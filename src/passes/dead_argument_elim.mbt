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
fn make_func_type(params : Array[ValType], results : Array[ValType]) -> RecType {
  single_rec_type(comp_type_sub_type(func_comp_type(params, results)))
}

///|
fn extract_comp_type(sub_type : SubType) -> CompType {
  match sub_type {
    SubType(_, _, comp) => comp
    CompTypeSubType(comp) => comp
  }
}

///|
fn resolve_func_type(comp_types : Array[CompType], idx : TypeIdx) -> FuncType? {
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
fn count_imported_funcs(mod : Module) -> Int {
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
fn collect_func_types(mod : Module) -> Array[FuncType] {
  let comp_types : Array[CompType] = []
  match mod.type_sec {
    Some(TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          SingleRecType(sub_type) =>
            comp_types.push(extract_comp_type(sub_type))
          GroupRecType(sub_types) =>
            for sub_type in sub_types {
              comp_types.push(extract_comp_type(sub_type))
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
            match resolve_func_type(comp_types, type_idx) {
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
        match resolve_func_type(comp_types, type_idx) {
          Some(ft) => func_types.push(ft)
          None => func_types.push(FuncType::new([], []))
        }
      }
    None => ()
  }
  func_types
}

///|
fn flattened_type_count(rec_types : Array[RecType]) -> Int {
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
fn is_literal_const(instr : TInstr) -> Bool {
  match instr {
    TI32Const(_) | TI64Const(_) | TF32Const(_) | TF64Const(_) => true
    TRefNull(_) | TRefFunc(_) => true
    TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) => true
    _ => false
  }
}

///|
fn is_trivially_pure_arg(instr : TInstr) -> Bool {
  match instr {
    TI32Const(_) | TI64Const(_) | TF32Const(_) | TF64Const(_) => true
    TRefNull(_) | TRefFunc(_) => true
    TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) => true
    TLocalGet(_) | TGlobalGet(_) => true
    _ => false
  }
}

///|
fn body_ends_with_explicit_return_or_unreachable(body : TExpr) -> Bool {
  if body.instrs.is_empty() {
    return true
  }
  match body.instrs[body.instrs.length() - 1] {
    TReturn(_) | TUnreachable => true
    _ => false
  }
}

///|
fn mark_exports_unseen(mod : Module, has_unseen : Array[Bool]) -> Unit {
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
fn mark_start_unseen(mod : Module, has_unseen : Array[Bool]) -> Unit {
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
fn mark_elem_unseen(mod : Module, has_unseen : Array[Bool]) -> Unit {
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
struct CallSite {
  caller_abs_idx : Int
  args : Array[TInstr]
} derive(Eq, Show)

///|
fn callsite(caller_abs_idx : Int, args : Array[TInstr]) -> CallSite {
  { caller_abs_idx, args }
}

///|
fn record_call(
  caller_abs_idx : Int,
  target : FuncIdx,
  args : Array[TInstr],
  calls_by_target : Array[Array[CallSite]],
  call_counts : Array[Int],
) -> Unit {
  let FuncIdx(raw) = target
  let idx = raw.reinterpret_as_int()
  if idx < 0 || idx >= calls_by_target.length() {
    return
  }
  call_counts[idx] += 1
  calls_by_target[idx].push(callsite(caller_abs_idx, args.copy()))
}

///|
fn analyze_function_body(
  abs_func_idx : Int,
  param_count : Int,
  body : TExpr,
  calls_by_target : Array[Array[CallSite]],
  call_counts : Array[Int],
  dropped_call_counts : Array[Int],
  has_unseen_calls : Array[Bool],
  has_tail_calls : Array[Bool],
  tail_callee : Array[Bool],
  return_callers : Array[Bool],
  used_params : Set[Int],
) -> Unit {
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TLocalGet(LocalIdx(raw)) => {
        let idx = raw.reinterpret_as_int()
        if idx >= 0 && idx < param_count {
          used_params.add(idx)
        }
      }
      TDrop(TCall(target, _)) => {
        let FuncIdx(raw) = target
        let idx = raw.reinterpret_as_int()
        if idx >= 0 && idx < dropped_call_counts.length() {
          dropped_call_counts[idx] += 1
        }
      }
      TCall(target, args) =>
        record_call(abs_func_idx, target, args, calls_by_target, call_counts)
      TReturnCall(target, args) => {
        record_call(abs_func_idx, target, args, calls_by_target, call_counts)
        let FuncIdx(raw) = target
        let idx = raw.reinterpret_as_int()
        if idx >= 0 && idx < tail_callee.length() {
          tail_callee[idx] = true
          return_callers[idx] = true
        }
        if abs_func_idx >= 0 && abs_func_idx < has_tail_calls.length() {
          has_tail_calls[abs_func_idx] = true
        }
      }
      TReturnCallIndirect(_, _, _, _) | TReturnCallRef(_, _, _) =>
        if abs_func_idx >= 0 && abs_func_idx < has_tail_calls.length() {
          has_tail_calls[abs_func_idx] = true
        }
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
fn compute_constant_params(
  param_types : Array[ValType],
  calls : Array[CallSite],
) -> Map[Int, TInstr] {
  let constants : Map[Int, TInstr] = Map::new()
  if calls.is_empty() {
    return constants
  }
  for p = 0; p < param_types.length(); p = p + 1 {
    let mut candidate : TInstr? = None
    let mut all_const = true
    for callsite in calls {
      let args = callsite.args
      if p >= args.length() {
        all_const = false
        break
      }
      let arg = args[p]
      if not(is_literal_const(arg)) {
        all_const = false
        break
      }
      match candidate {
        None => candidate = Some(arg)
        Some(prev) =>
          if prev != arg {
            all_const = false
            break
          }
      }
    }
    if all_const {
      match candidate {
        Some(c) => constants.set(p, c)
        None => ()
      }
    }
  }
  constants
}

///|
fn all_calls_arg_pure(calls : Array[CallSite], param_idx : Int) -> Bool {
  for callsite in calls {
    let args = callsite.args
    if param_idx >= args.length() {
      return false
    }
    if not(is_trivially_pure_arg(args[param_idx])) {
      return false
    }
  }
  true
}

///|
fn collect_global_types(mod : Module) -> Array[ValType] {
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
fn build_local_types_by_abs(
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
fn known_instr_type(
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
        known_instr_type(
          value, caller_abs_idx, local_types_by_abs, global_types, env,
        ) {
        Some(RefTypeValType(rt)) =>
          Some(ValType::ref_type(RefType::new(false, rt.get_heap_type())))
        _ => None
      }
    TRefCast(nullable, ht, _) =>
      Some(ValType::ref_type(RefType::new(nullable, ht)))
    TSelect(Some(types), _, _, _) if types.length() == 1 => Some(types[0])
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
fn common_supertype(a : ValType, b : ValType, env : Env) -> ValType? {
  if Match::matches(a, b, env) {
    return Some(b)
  }
  if Match::matches(b, a, env) {
    return Some(a)
  }
  None
}

///|
fn refine_param_types(
  old_params : Array[ValType],
  calls : Array[CallSite],
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
        known_instr_type(
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
            Some(prev) => common_supertype(prev, arg_ty, env)
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
fn collect_explicit_return_types(
  body : TExpr,
  result_arity : Int,
  abs_func_idx : Int,
  local_types_by_abs : Array[Array[ValType]],
  global_types : Array[ValType],
  env : Env,
) -> Array[Array[ValType]]? {
  let rows : Array[Array[ValType]] = []
  let mut failed = false
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TReturn(values) =>
        if values.length() != result_arity {
          failed = true
        } else {
          let row : Array[ValType] = []
          for value in values {
            match
              known_instr_type(
                value, abs_func_idx, local_types_by_abs, global_types, env,
              ) {
              Some(vt) => row.push(vt)
              None => {
                failed = true
                break
              }
            }
          }
          if row.length() == result_arity {
            rows.push(row)
          }
        }
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), body))
  if failed {
    None
  } else {
    Some(rows)
  }
}

///|
fn refine_return_types(
  old_results : Array[ValType],
  body : TExpr,
  abs_func_idx : Int,
  local_types_by_abs : Array[Array[ValType]],
  global_types : Array[ValType],
  env : Env,
) -> Array[ValType] {
  if old_results.is_empty() {
    return old_results
  }
  let rows = match
    collect_explicit_return_types(
      body,
      old_results.length(),
      abs_func_idx,
      local_types_by_abs,
      global_types,
      env,
    ) {
    Some(r) => r
    None => return old_results
  }
  if rows.is_empty() {
    return old_results
  }
  let new_results = old_results.copy()
  for i = 0; i < old_results.length(); i = i + 1 {
    let mut candidate = rows[0][i]
    for row_i = 1; row_i < rows.length(); row_i = row_i + 1 {
      match common_supertype(candidate, rows[row_i][i], env) {
        Some(c) => candidate = c
        None => return old_results
      }
    }
    if not(Match::matches(candidate, old_results[i], env)) {
      return old_results
    }
    new_results[i] = candidate
  }
  new_results
}

///|
fn count_removed_params(
  param_count : Int,
  removed_unused : Set[Int],
  removed_const : Map[Int, TInstr],
) -> Int {
  let mut n = 0
  for p = 0; p < param_count; p = p + 1 {
    if removed_unused.contains(p) || removed_const.contains(p) {
      n += 1
    }
  }
  n
}

///|
fn rewrite_local_index(
  idx : Int,
  old_param_count : Int,
  removed_unused : Set[Int],
  removed_const : Map[Int, TInstr],
  const_local_slots : Map[Int, Int],
  removed_total : Int,
) -> Int? {
  if idx < 0 {
    return Some(idx)
  }
  if idx < old_param_count {
    if removed_unused.contains(idx) {
      return None
    }
    if removed_const.contains(idx) {
      return const_local_slots.get(idx)
    }
    let mut removed_before = 0
    for p = 0; p < idx; p = p + 1 {
      if removed_unused.contains(p) || removed_const.contains(p) {
        removed_before += 1
      }
    }
    return Some(idx - removed_before)
  }
  Some(idx - removed_total)
}

///|
fn build_local_plan(
  old_locals : Array[ValType],
  old_param_types : Array[ValType],
  removed_unused : Set[Int],
  removed_const : Map[Int, TInstr],
) -> (Array[ValType], Array[TInstr], Int, Map[Int, Int]) {
  let old_param_count = old_param_types.length()
  let removed_total = count_removed_params(
    old_param_count, removed_unused, removed_const,
  )
  let new_param_count = old_param_count - removed_total
  let new_locals = old_locals.copy()
  let prologue : Array[TInstr] = []
  let const_local_slots : Map[Int, Int] = Map::new()
  for p = 0; p < old_param_count; p = p + 1 {
    match removed_const.get(p) {
      Some(const_val) => {
        let local_offset = new_locals.length()
        new_locals.push(old_param_types[p])
        let local_idx = new_param_count + local_offset
        const_local_slots.set(p, local_idx)
        prologue.push(
          TInstr::local_set(
            LocalIdx::new(local_idx.reinterpret_as_uint()),
            const_val,
          ),
        )
      }
      None => ()
    }
  }
  (new_locals, prologue, removed_total, const_local_slots)
}

///|
fn rewrite_locals_and_returns(
  body : TExpr,
  old_param_count : Int,
  removed_unused : Set[Int],
  removed_const : Map[Int, TInstr],
  const_local_slots : Map[Int, Int],
  removed_total : Int,
  remove_result : Bool,
) -> TExpr {
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    let processed = match self.walk_tinstruction_default((), instr) {
      Ok(Some((_, i))) => i
      Ok(None) => instr
      Err(e) => return Err(e)
    }
    match processed {
      TLocalGet(LocalIdx(raw)) => {
        let idx = raw.reinterpret_as_int()
        match
          rewrite_local_index(
            idx, old_param_count, removed_unused, removed_const, const_local_slots,
            removed_total,
          ) {
          Some(new_idx) =>
            if new_idx == idx {
              if processed != instr {
                change((), processed)
              } else {
                unchanged()
              }
            } else {
              change(
                (),
                TInstr::local_get(LocalIdx::new(new_idx.reinterpret_as_uint())),
              )
            }
          None => change((), TInstr::unreachable_())
        }
      }
      TLocalSet(LocalIdx(raw), value) => {
        let idx = raw.reinterpret_as_int()
        match
          rewrite_local_index(
            idx, old_param_count, removed_unused, removed_const, const_local_slots,
            removed_total,
          ) {
          Some(new_idx) =>
            if new_idx == idx {
              if processed != instr {
                change((), processed)
              } else {
                unchanged()
              }
            } else {
              change(
                (),
                TInstr::local_set(
                  LocalIdx::new(new_idx.reinterpret_as_uint()),
                  value,
                ),
              )
            }
          None => change((), TInstr::drop(value))
        }
      }
      TLocalTee(LocalIdx(raw), value) => {
        let idx = raw.reinterpret_as_int()
        match
          rewrite_local_index(
            idx, old_param_count, removed_unused, removed_const, const_local_slots,
            removed_total,
          ) {
          Some(new_idx) =>
            if new_idx == idx {
              if processed != instr {
                change((), processed)
              } else {
                unchanged()
              }
            } else {
              change(
                (),
                TInstr::local_tee(
                  LocalIdx::new(new_idx.reinterpret_as_uint()),
                  value,
                ),
              )
            }
          None => change((), value)
        }
      }
      TReturn(values) if remove_result && values.length() > 0 =>
        change((), TInstr::return_([]))
      _ => if processed != instr { change((), processed) } else { unchanged() }
    }
  })
  match walker.walk_texpr((), body) {
    Ok(Some((_, new_body))) => new_body
    _ => body
  }
}

///|
fn filter_call_args(args : Array[TInstr], removed : Set[Int]) -> Array[TInstr] {
  if removed.is_empty() {
    return args
  }
  let out : Array[TInstr] = []
  for i = 0; i < args.length(); i = i + 1 {
    if not(removed.contains(i)) {
      out.push(args[i])
    }
  }
  out
}

///|
fn rewrite_calls(
  body : TExpr,
  removed_params_by_target : Array[Set[Int]],
  result_removed_by_target : Array[Bool],
  target_remap : Array[Int],
) -> TExpr {
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    let processed = match self.walk_tinstruction_default((), instr) {
      Ok(Some((_, i))) => i
      Ok(None) => instr
      Err(e) => return Err(e)
    }
    match processed {
      TDrop(TCall(target, args)) => {
        let FuncIdx(raw) = target
        let idx = raw.reinterpret_as_int()
        if idx < 0 || idx >= removed_params_by_target.length() {
          return if processed != instr {
            change((), processed)
          } else {
            unchanged()
          }
        }
        let remapped = target_remap[idx]
        let new_target = FuncIdx::new(remapped.reinterpret_as_uint())
        let new_args = filter_call_args(args, removed_params_by_target[idx])
        if result_removed_by_target[idx] {
          change((), TInstr::call(new_target, new_args))
        } else if new_args != args {
          change((), TInstr::drop(TInstr::call(new_target, new_args)))
        } else if remapped != idx {
          change((), TInstr::drop(TInstr::call(new_target, new_args)))
        } else if processed != instr {
          change((), processed)
        } else {
          unchanged()
        }
      }
      TCall(target, args) => {
        let FuncIdx(raw) = target
        let idx = raw.reinterpret_as_int()
        if idx < 0 || idx >= removed_params_by_target.length() {
          return if processed != instr {
            change((), processed)
          } else {
            unchanged()
          }
        }
        let remapped = target_remap[idx]
        let new_target = FuncIdx::new(remapped.reinterpret_as_uint())
        let new_args = filter_call_args(args, removed_params_by_target[idx])
        if new_args != args || remapped != idx {
          change((), TInstr::call(new_target, new_args))
        } else if processed != instr {
          change((), processed)
        } else {
          unchanged()
        }
      }
      TReturnCall(target, args) => {
        let FuncIdx(raw) = target
        let idx = raw.reinterpret_as_int()
        if idx < 0 || idx >= removed_params_by_target.length() {
          return if processed != instr {
            change((), processed)
          } else {
            unchanged()
          }
        }
        let remapped = target_remap[idx]
        let new_target = FuncIdx::new(remapped.reinterpret_as_uint())
        let new_args = filter_call_args(args, removed_params_by_target[idx])
        if new_args != args || remapped != idx {
          change((), TInstr::return_call(new_target, new_args))
        } else if processed != instr {
          change((), processed)
        } else {
          unchanged()
        }
      }
      _ => if processed != instr { change((), processed) } else { unchanged() }
    }
  })
  match walker.walk_texpr((), body) {
    Ok(Some((_, new_body))) => new_body
    _ => body
  }
}

///|
fn make_adapter_thunk(
  target_abs_idx : Int,
  old_params : Array[ValType],
  old_results : Array[ValType],
  removed_unused : Set[Int],
  removed_const : Map[Int, TInstr],
  remove_result : Bool,
) -> Func {
  let call_args : Array[TInstr] = []
  for p = 0; p < old_params.length(); p = p + 1 {
    if removed_unused.contains(p) {
      continue
    }
    match removed_const.get(p) {
      Some(v) => call_args.push(v)
      None =>
        call_args.push(
          TInstr::local_get(LocalIdx::new(p.reinterpret_as_uint())),
        )
    }
  }
  let target = FuncIdx::new(target_abs_idx.reinterpret_as_uint())
  let body = if remove_result {
    TExpr::new([TInstr::call(target, call_args), TInstr::return_([])])
  } else if old_results.length() == 0 {
    TExpr::new([TInstr::call(target, call_args), TInstr::return_([])])
  } else {
    TExpr::new([TInstr::return_([TInstr::call(target, call_args)])])
  }
  Func::t_func([], body)
}

///|
fn run_dead_argument_elim(mod : Module) -> Module {
  let funcs = match mod.code_sec {
    Some(CodeSec(funcs)) => funcs
    None => return mod
  }
  let func_sec = match mod.func_sec {
    Some(FuncSec(type_idxs)) => type_idxs
    None => return mod
  }
  if funcs.is_empty() {
    return mod
  }
  let func_types = collect_func_types(mod)
  let total_func_count = func_types.length()
  if total_func_count == 0 {
    return mod
  }
  let import_func_count = count_imported_funcs(mod)
  let calls_by_target : Array[Array[CallSite]] = []
  for i = 0; i < total_func_count; i = i + 1 {
    ignore(i)
    calls_by_target.push([])
  }
  let env = Env::new().with_module(mod)
  let local_types_by_abs = build_local_types_by_abs(
    func_types, funcs, import_func_count,
  )
  let global_types = collect_global_types(mod)
  let call_counts : Array[Int] = Array::make(total_func_count, 0)
  let dropped_call_counts : Array[Int] = Array::make(total_func_count, 0)
  let has_unseen_calls : Array[Bool] = Array::make(total_func_count, false)
  let has_tail_calls : Array[Bool] = Array::make(total_func_count, false)
  let tail_callee : Array[Bool] = Array::make(total_func_count, false)
  let return_callers : Array[Bool] = Array::make(total_func_count, false)
  mark_exports_unseen(mod, has_unseen_calls)
  mark_start_unseen(mod, has_unseen_calls)
  mark_elem_unseen(mod, has_unseen_calls)
  let used_params_by_defined : Array[Set[Int]] = []
  let body_can_remove_result : Array[Bool] = []
  for i = 0; i < funcs.length(); i = i + 1 {
    let abs_idx = import_func_count + i
    let used_params : Set[Int] = Set::new()
    used_params_by_defined.push(used_params)
    match funcs[i] {
      TFunc(_, body) => {
        body_can_remove_result.push(
          body_ends_with_explicit_return_or_unreachable(body),
        )
        if abs_idx >= 0 && abs_idx < total_func_count {
          let FuncType(params, _) = func_types[abs_idx]
          analyze_function_body(
            abs_idx,
            params.length(),
            body,
            calls_by_target,
            call_counts,
            dropped_call_counts,
            has_unseen_calls,
            has_tail_calls,
            tail_callee,
            return_callers,
            used_params,
          )
        }
      }
      _ => body_can_remove_result.push(false)
    }
  }
  let removed_unused_by_defined : Array[Set[Int]] = []
  let removed_const_by_defined : Array[Map[Int, TInstr]] = []
  let result_removed_by_defined : Array[Bool] = []
  let refined_params_by_defined : Array[Array[ValType]] = []
  let refined_results_by_defined : Array[Array[ValType]] = []
  let removed_params_by_target : Array[Set[Int]] = []
  for i = 0; i < total_func_count; i = i + 1 {
    ignore(i)
    removed_params_by_target.push(Set::new())
  }
  let result_removed_by_target : Array[Bool] = Array::make(
    total_func_count, false,
  )
  for i = 0; i < funcs.length(); i = i + 1 {
    let abs_idx = import_func_count + i
    let removed_unused : Set[Int] = Set::new()
    let removed_const : Map[Int, TInstr] = Map::new()
    let mut remove_result = false
    let mut refined_params : Array[ValType] = []
    let mut refined_results : Array[ValType] = []
    if abs_idx >= 0 && abs_idx < total_func_count {
      let FuncType(params, results) = func_types[abs_idx]
      let calls = calls_by_target[abs_idx]
      let used_params = used_params_by_defined[i]
      refined_params = if has_unseen_calls[abs_idx] {
        params.copy()
      } else {
        refine_param_types(params, calls, local_types_by_abs, global_types, env)
      }
      refined_results = if has_tail_calls[abs_idx] {
        results.copy()
      } else {
        match funcs[i] {
          TFunc(_, body) =>
            refine_return_types(
              results, body, abs_idx, local_types_by_abs, global_types, env,
            )
          _ => results.copy()
        }
      }
      if not(return_callers[abs_idx]) && not(calls.is_empty()) {
        let constants = if has_unseen_calls[abs_idx] {
          Map::new()
        } else {
          compute_constant_params(refined_params, calls)
        }
        for p = 0; p < refined_params.length(); p = p + 1 {
          if not(all_calls_arg_pure(calls, p)) {
            continue
          }
          if not(has_unseen_calls[abs_idx]) {
            match constants.get(p) {
              Some(c) => removed_const.set(p, c)
              None => if not(used_params.contains(p)) { removed_unused.add(p) }
            }
          } else if not(used_params.contains(p)) {
            removed_unused.add(p)
          }
        }
      }
      let removed_all : Set[Int] = Set::new()
      for p = 0; p < refined_params.length(); p = p + 1 {
        if removed_unused.contains(p) || removed_const.contains(p) {
          removed_all.add(p)
        }
      }
      removed_params_by_target[abs_idx] = removed_all
      if not(has_unseen_calls[abs_idx]) &&
        not(return_callers[abs_idx]) &&
        not(has_tail_calls[abs_idx]) &&
        not(tail_callee[abs_idx]) &&
        results.length() > 0 &&
        call_counts[abs_idx] > 0 &&
        call_counts[abs_idx] == dropped_call_counts[abs_idx] &&
        body_can_remove_result[i] {
        remove_result = true
        result_removed_by_target[abs_idx] = true
      }
    } else {
      refined_params = []
      refined_results = []
    }
    removed_unused_by_defined.push(removed_unused)
    removed_const_by_defined.push(removed_const)
    result_removed_by_defined.push(remove_result)
    refined_params_by_defined.push(refined_params)
    refined_results_by_defined.push(refined_results)
  }
  let type_recs = match mod.type_sec {
    Some(TypeSec(rs)) => rs.copy()
    None => []
  }
  let func_type_idxs = func_sec.copy()
  let mut flat_type_count = flattened_type_count(type_recs)
  let mut signature_changed = false
  let has_signature_change_by_defined : Array[Bool] = Array::make(
    funcs.length(),
    false,
  )
  let adapted_by_defined : Array[Bool] = Array::make(funcs.length(), false)
  let cloned_new_type_idx_by_defined : Array[TypeIdx?] = Array::make(
    funcs.length(),
    None,
  )
  let target_remap : Array[Int] = []
  for i = 0; i < total_func_count; i = i + 1 {
    target_remap.push(i)
  }
  let old_total_func_count = total_func_count
  let mut appended_clones = 0
  for i = 0; i < funcs.length() && i < func_type_idxs.length(); i = i + 1 {
    let abs_idx = import_func_count + i
    if abs_idx < 0 || abs_idx >= total_func_count {
      continue
    }
    let removed = removed_params_by_target[abs_idx]
    let remove_result = result_removed_by_target[abs_idx]
    let FuncType(old_params, old_results) = func_types[abs_idx]
    let refined_params = refined_params_by_defined[i]
    let refined_results = refined_results_by_defined[i]
    let params_refined = refined_params != old_params
    let results_refined = refined_results != old_results
    if removed.is_empty() &&
      not(remove_result) &&
      not(params_refined) &&
      not(results_refined) {
      continue
    }
    has_signature_change_by_defined[i] = true
    if has_unseen_calls[abs_idx] && old_results.length() > 1 {
      has_signature_change_by_defined[i] = false
      removed_params_by_target[abs_idx].clear()
      result_removed_by_target[abs_idx] = false
      removed_unused_by_defined[i].clear()
      removed_const_by_defined[i].clear()
      result_removed_by_defined[i] = false
      refined_params_by_defined[i] = old_params.copy()
      refined_results_by_defined[i] = old_results.copy()
      continue
    }
    let new_params : Array[ValType] = []
    for p = 0; p < refined_params.length(); p = p + 1 {
      if not(removed.contains(p)) {
        new_params.push(refined_params[p])
      }
    }
    let new_results = if remove_result { [] } else { refined_results.copy() }
    type_recs.push(make_func_type(new_params, new_results))
    let new_type_idx = TypeIdx::new(flat_type_count.reinterpret_as_uint())
    flat_type_count += 1
    if has_unseen_calls[abs_idx] {
      adapted_by_defined[i] = true
      cloned_new_type_idx_by_defined[i] = Some(new_type_idx)
      let new_abs_idx = old_total_func_count + appended_clones
      target_remap[abs_idx] = new_abs_idx
      appended_clones += 1
    } else {
      func_type_idxs[i] = new_type_idx
    }
    signature_changed = true
  }
  if appended_clones > 0 {
    for i = 0; i < funcs.length(); i = i + 1 {
      if not(adapted_by_defined[i]) {
        continue
      }
      match cloned_new_type_idx_by_defined[i] {
        Some(type_idx) => func_type_idxs.push(type_idx)
        None => ()
      }
    }
  }
  let mut out_mod = mod
  if signature_changed {
    out_mod = out_mod
      .with_type_sec(TypeSec::new(type_recs))
      .with_func_sec(FuncSec::new(func_type_idxs))
  }
  let new_funcs : Array[Func] = []
  let appended_clones_funcs : Array[Func] = []
  let mut body_changed = false
  for i = 0; i < funcs.length(); i = i + 1 {
    let abs_idx = import_func_count + i
    match funcs[i] {
      TFunc(locals, body) if abs_idx >= 0 && abs_idx < total_func_count => {
        let FuncType(old_params, _) = func_types[abs_idx]
        let removed_unused = removed_unused_by_defined[i]
        let removed_const = removed_const_by_defined[i]
        let remove_result = result_removed_by_defined[i]
        let (new_locals, prologue, removed_total, const_local_slots) = build_local_plan(
          locals, old_params, removed_unused, removed_const,
        )
        let body1 = rewrite_locals_and_returns(
          body,
          old_params.length(),
          removed_unused,
          removed_const,
          const_local_slots,
          removed_total,
          remove_result,
        )
        let body2 = rewrite_calls(
          body1, removed_params_by_target, result_removed_by_target, target_remap,
        )
        let final_body = if prologue.is_empty() {
          body2
        } else {
          TExpr::new([..prologue, ..body2.instrs])
        }
        let new_func = Func::t_func(new_locals, final_body)
        if adapted_by_defined[i] {
          let FuncType(old_params, old_results) = func_types[abs_idx]
          let thunk = make_adapter_thunk(
            target_remap[abs_idx],
            old_params,
            old_results,
            removed_unused,
            removed_const,
            remove_result,
          )
          if thunk != funcs[i] {
            body_changed = true
          }
          new_funcs.push(thunk)
          appended_clones_funcs.push(new_func)
        } else {
          new_funcs.push(new_func)
        }
        if new_func != funcs[i] || has_signature_change_by_defined[i] {
          body_changed = true
        }
      }
      TFunc(_, body) => {
        let rewritten = rewrite_calls(
          body, removed_params_by_target, result_removed_by_target, target_remap,
        )
        if rewritten != body {
          body_changed = true
          match funcs[i] {
            TFunc(ls, _) => new_funcs.push(Func::t_func(ls, rewritten))
            _ => new_funcs.push(funcs[i])
          }
        } else {
          new_funcs.push(funcs[i])
        }
      }
      _ => new_funcs.push(funcs[i])
    }
  }
  for clone in appended_clones_funcs {
    new_funcs.push(clone)
  }
  if not(signature_changed) && not(body_changed) {
    return mod
  }
  out_mod.with_code_sec(CodeSec::new(new_funcs))
}

///|
fn dead_argument_elim_pass(mod : Module) -> ModuleTransformer[IRContext] {
  let rewritten = run_dead_argument_elim(mod)
  let rewritten_code = rewritten.code_sec
  let rewritten_types = rewritten.type_sec
  let rewritten_funcs = rewritten.func_sec
  ModuleTransformer::new()
  .on_typesec_evt(fn(_, ctx : IRContext, type_sec : TypeSec) {
    match rewritten_types {
      Some(new_type_sec) =>
        if new_type_sec == type_sec {
          unchanged()
        } else {
          change(ctx, new_type_sec)
        }
      None => unchanged()
    }
  })
  .on_funcsec_evt(fn(_, ctx : IRContext, func_sec : FuncSec) {
    match rewritten_funcs {
      Some(new_func_sec) =>
        if new_func_sec == func_sec {
          unchanged()
        } else {
          change(ctx, new_func_sec)
        }
      None => unchanged()
    }
  })
  .on_codesec_evt(fn(_, ctx : IRContext, code_sec : CodeSec) {
    match rewritten_code {
      Some(new_code) =>
        if new_code == code_sec {
          unchanged()
        } else {
          change(ctx, new_code)
        }
      None => unchanged()
    }
  })
}

///|
test "dead argument elimination removes unused params from signatures" {
  // f0() -> i32: call f1(i32.const 9)
  // f1(i32) -> i32: parameter unused, returns const
  let caller = Func::t_func(
    [],
    TExpr::new([TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(9))])]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::i32_const(I32(7))]))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        make_func_type([ValType::i32()], [ValType::i32()]),
        make_func_type([], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([caller, callee]))
  let optimized = run_dead_argument_elim(mod)
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, { instrs: [TCall(_, args)], .. }), _])) =>
      assert_eq(args.length(), 0)
    _ => fail("expected rewritten call argument list")
  }
  match optimized.func_sec {
    Some(FuncSec(type_idxs)) =>
      // callee got a fresh, appended type index
      assert_eq(type_idxs[1], TypeIdx::new(2))
    None => fail("expected func section")
  }
}

///|
test "dead argument elimination removes constant params and seeds entry local" {
  // f0() -> i32: call f1(i32.const 42)
  // f1(i32) -> i32: returns local.get 0
  let caller = Func::t_func(
    [],
    TExpr::new([TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(42))])]),
  )
  let callee = Func::t_func(
    [],
    TExpr::new([TInstr::local_get(LocalIdx::new(0))]),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        make_func_type([ValType::i32()], [ValType::i32()]),
        make_func_type([], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([caller, callee]))
  let optimized = run_dead_argument_elim(mod)
  match optimized.code_sec {
    Some(CodeSec([_, TFunc(_, { instrs, .. })])) => {
      assert_true(instrs.length() >= 2)
      assert_eq(
        instrs[0],
        TInstr::local_set(LocalIdx::new(0), TInstr::i32_const(I32(42))),
      )
    }
    _ => fail("expected seeded callee entry")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, { instrs: [TCall(_, args)], .. }), _])) =>
      assert_eq(args.length(), 0)
    _ => fail("expected rewritten caller args")
  }
}

///|
test "dead argument elimination removes dropped return values from signatures" {
  // f0() -> none: drop(call f1()) ; return
  // f1() -> i32: return i32.const 7
  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::drop(TInstr::call(FuncIdx::new(1), [])),
      TInstr::return_([]),
    ]),
  )
  let callee = Func::t_func(
    [],
    TExpr::new([TInstr::return_([TInstr::i32_const(I32(7))])]),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        make_func_type([], [ValType::i32()]),
        make_func_type([], []),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([caller, callee]))
  let optimized = run_dead_argument_elim(mod)
  match optimized.code_sec {
    Some(
      CodeSec(
        [TFunc(_, { instrs: instrs0, .. }), TFunc(_, { instrs: instrs1, .. })]
      )
    ) => {
      assert_true(instrs0[0] is TCall(_, []))
      assert_eq(instrs1[0], TInstr::return_([]))
    }
    _ => fail("expected rewritten drop/callee return")
  }
  match optimized.func_sec {
    Some(FuncSec(type_idxs)) =>
      // callee got a fresh () -> () type.
      assert_eq(type_idxs[1], TypeIdx::new(2))
    None => fail("expected func section")
  }
}

///|
test "dead argument elimination handles exported callee via adapter thunk" {
  // f0 directly calls exported f1(i32) where the parameter is unused.
  let caller = Func::t_func(
    [],
    TExpr::new([TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(9))])]),
  )
  let exported_callee = Func::t_func(
    [],
    TExpr::new([TInstr::i32_const(I32(7))]),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        make_func_type([ValType::i32()], [ValType::i32()]),
        make_func_type([], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([caller, exported_callee]))
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("f1"), ExternIdx::func(FuncIdx::new(1))),
      ]),
    )
  let optimized = run_dead_argument_elim(mod)
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, { instrs: instrs0, .. }), _, _])) => {
      let mut found = false
      for instr in instrs0 {
        match instr {
          TCall(FuncIdx(2), args) => {
            found = true
            assert_eq(args.length(), 0)
          }
          _ => ()
        }
      }
      assert_true(found)
    }
    _ => fail("expected clone for exported function")
  }
}

///|
test "dead argument elimination handles table-reachable callee via adapter thunk" {
  // f1 appears in table elems, so it is unseen/indirectly reachable.
  let caller = Func::t_func(
    [],
    TExpr::new([TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(9))])]),
  )
  let table_callee = Func::t_func([], TExpr::new([TInstr::i32_const(I32(7))]))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        make_func_type([ValType::i32()], [ValType::i32()]),
        make_func_type([], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1), TypeIdx::new(0)]))
    .with_table_sec(
      TableSec::new([
        Table::new(
          TableType::new(
            RefType::new(true, HeapType::abs(AbsHeapType::func())),
            Limits::i32(1, Some(1)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      ElemSec::new([
        Elem::new(
          ElemMode::active(
            table_idx(0),
            Expr::new([Instruction::i32_const(I32(0))]),
          ),
          ElemKind::funcs([func_idx(1)]),
        ),
      ]),
    )
    .with_code_sec(CodeSec::new([caller, table_callee]))
  let optimized = run_dead_argument_elim(mod)
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, { instrs: instrs0, .. }), _, _])) => {
      let mut found = false
      for instr in instrs0 {
        match instr {
          TCall(FuncIdx(2), args) => {
            found = true
            assert_eq(args.length(), 0)
          }
          _ => ()
        }
      }
      assert_true(found)
    }
    _ => fail("expected clone for table-reachable function")
  }
}

///|
test "dead argument elimination refines parameter reference types" {
  // f0((ref func)) -> i32: call f1(local.get 0)
  // f1((ref null func)) -> i32, and uses the param
  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), [TInstr::local_get(LocalIdx::new(0))]),
    ]),
  )
  let callee = Func::t_func(
    [],
    TExpr::new([
      TInstr::drop(TInstr::local_get(LocalIdx::new(0))),
      TInstr::i32_const(I32(7)),
    ]),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        make_func_type(
          [
            ValType::ref_type(
              RefType::new(false, HeapType::abs(AbsHeapType::func())),
            ),
          ],
          [ValType::i32()],
        ),
        make_func_type(
          [
            ValType::ref_type(
              RefType::new(true, HeapType::abs(AbsHeapType::func())),
            ),
          ],
          [ValType::i32()],
        ),
        make_func_type([], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([caller, callee]))
  let optimized = run_dead_argument_elim(mod)
  let all_types = collect_func_types(optimized)
  let FuncType(params, _) = all_types[1]
  assert_eq(
    params[0],
    ValType::ref_type(RefType::new(false, HeapType::abs(AbsHeapType::func()))),
  )
}

///|
test "dead argument elimination refines return reference types" {
  // f0((ref func)) -> (ref null func): call f1(local.get 0)
  // f1((ref func)) -> (ref null func): returns local.get 0, so result can refine to non-null.
  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::call(FuncIdx::new(1), [TInstr::local_get(LocalIdx::new(0))]),
    ]),
  )
  let callee = Func::t_func(
    [],
    TExpr::new([TInstr::return_([TInstr::local_get(LocalIdx::new(0))])]),
  )
  let non_null_funcref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::func())),
  )
  let nullable_funcref = ValType::ref_type(
    RefType::new(true, HeapType::abs(AbsHeapType::func())),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        make_func_type([non_null_funcref], [nullable_funcref]),
        make_func_type([non_null_funcref], [nullable_funcref]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0), TypeIdx::new(1)]))
    .with_code_sec(CodeSec::new([caller, callee]))
  let optimized = run_dead_argument_elim(mod)
  let all_types = collect_func_types(optimized)
  let FuncType(_, callee_results) = all_types[1]
  assert_eq(
    callee_results[0],
    ValType::ref_type(RefType::new(false, HeapType::abs(AbsHeapType::func()))),
  )
}
