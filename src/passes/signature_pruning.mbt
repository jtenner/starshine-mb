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
fn sp_make_func_type(
  params : Array[ValType],
  results : Array[ValType],
) -> RecType {
  single_rec_type(comp_type_sub_type(func_comp_type(params, results)))
}

///|
fn sp_extract_comp_type(sub_type : SubType) -> CompType {
  match sub_type {
    SubType(_, _, comp) => comp
    CompTypeSubType(comp) => comp
  }
}

///|
fn sp_flattened_type_count(rec_types : Array[RecType]) -> Int {
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
fn sp_resolve_type_idx(
  type_idx : TypeIdx,
  group_start : Int,
  total : Int,
) -> Int? {
  let idx = match type_idx {
    TypeIdx(i) => i.reinterpret_as_int()
    RecIdx(i) => group_start + i.reinterpret_as_int()
  }
  if idx < 0 || idx >= total {
    None
  } else {
    Some(idx)
  }
}

///|
fn sp_typeidx_raw(type_idx : TypeIdx) -> Int {
  match type_idx {
    TypeIdx(i) => i.reinterpret_as_int()
    RecIdx(i) => i.reinterpret_as_int()
  }
}

///|
fn sp_resolve_func_type(
  comp_types : Array[CompType],
  idx : TypeIdx,
) -> FuncType? {
  let j = sp_typeidx_raw(idx)
  if j < 0 || j >= comp_types.length() {
    return None
  }
  match comp_types[j] {
    FuncCompType(params, results) => Some(FuncType::new(params, results))
    _ => None
  }
}

///|
fn sp_collect_func_types(mod : Module) -> Array[FuncType] {
  let comp_types : Array[CompType] = []
  match mod.type_sec {
    Some(TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          SingleRecType(sub_type) =>
            comp_types.push(sp_extract_comp_type(sub_type))
          GroupRecType(sub_types) =>
            for sub_type in sub_types {
              comp_types.push(sp_extract_comp_type(sub_type))
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
            match sp_resolve_func_type(comp_types, type_idx) {
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
        match sp_resolve_func_type(comp_types, type_idx) {
          Some(ft) => func_types.push(ft)
          None => func_types.push(FuncType::new([], []))
        }
      }
    None => ()
  }
  func_types
}

///|
fn sp_count_imported_funcs(mod : Module) -> Int {
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
fn sp_collect_func_type_idxs(mod : Module) -> Array[TypeIdx] {
  let out : Array[TypeIdx] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        let Import(_, _, ex) = import_
        match ex {
          FuncExternType(type_idx) => out.push(type_idx)
          _ => ()
        }
      }
    None => ()
  }
  match mod.func_sec {
    Some(FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        out.push(type_idx)
      }
    None => ()
  }
  out
}

///|
priv struct SPCallSite {
  args : Array[TInstr]
}

///|
fn sp_callsite(args : Array[TInstr]) -> SPCallSite {
  { args, }
}

///|
fn sp_is_literal_const(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_) => true
    TInstrKind::TRefNull(_) | TInstrKind::TRefFunc(_) => true
    TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      true
    _ => false
  }
}

///|
fn sp_is_trivially_pure_arg(instr : TInstr) -> Bool {
  match instr.kind {
    TInstrKind::TI32Const(_)
    | TInstrKind::TI64Const(_)
    | TInstrKind::TF32Const(_)
    | TInstrKind::TF64Const(_) => true
    TInstrKind::TRefNull(_) | TInstrKind::TRefFunc(_) => true
    TInstrKind::TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      true
    TInstrKind::TLocalGet(_) | TInstrKind::TGlobalGet(_) => true
    _ => false
  }
}

///|
fn sp_all_calls_arg_pure(calls : Array[SPCallSite], param_idx : Int) -> Bool {
  for callsite in calls {
    let args = callsite.args
    if param_idx >= args.length() {
      return false
    }
    if !sp_is_trivially_pure_arg(args[param_idx]) {
      return false
    }
  }
  true
}

///|
fn sp_filter_call_args(
  args : Array[TInstr],
  removed : Set[Int],
) -> Array[TInstr] {
  if removed.is_empty() {
    return args
  }
  let out : Array[TInstr] = []
  for i = 0; i < args.length(); i = i + 1 {
    if !removed.contains(i) {
      out.push(args[i])
    }
  }
  out
}

///|
fn sp_rewrite_calls(
  body : TExpr,
  func_type_idxs : Array[TypeIdx],
  removed_by_type_abs : Map[Int, Set[Int]],
  new_type_idx_by_old_abs : Map[Int, TypeIdx],
) -> TExpr {
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    let processed = match self.walk_tinstruction_default((), instr) {
      Ok(Some((_, i))) => i
      Ok(None) => instr
      Err(e) => return Err(e)
    }
    match processed.kind {
      TInstrKind::TCall(target, args) => {
        let FuncIdx(raw) = target
        let abs_idx = raw.reinterpret_as_int()
        if abs_idx < 0 || abs_idx >= func_type_idxs.length() {
          return if processed != instr {
            change((), processed)
          } else {
            unchanged()
          }
        }
        let old_type_abs = sp_typeidx_raw(func_type_idxs[abs_idx])
        match removed_by_type_abs.get(old_type_abs) {
          Some(removed) =>
            if removed.is_empty() {
              if processed != instr {
                change((), processed)
              } else {
                unchanged()
              }
            } else {
              let new_args = sp_filter_call_args(args, removed)
              if new_args != args || processed != instr {
                change((), TInstr::call(target, new_args))
              } else {
                unchanged()
              }
            }
          None =>
            if processed != instr {
              change((), processed)
            } else {
              unchanged()
            }
        }
      }
      TInstrKind::TReturnCall(target, args) => {
        let FuncIdx(raw) = target
        let abs_idx = raw.reinterpret_as_int()
        if abs_idx < 0 || abs_idx >= func_type_idxs.length() {
          return if processed != instr {
            change((), processed)
          } else {
            unchanged()
          }
        }
        let old_type_abs = sp_typeidx_raw(func_type_idxs[abs_idx])
        match removed_by_type_abs.get(old_type_abs) {
          Some(removed) =>
            if removed.is_empty() {
              if processed != instr {
                change((), processed)
              } else {
                unchanged()
              }
            } else {
              let new_args = sp_filter_call_args(args, removed)
              if new_args != args || processed != instr {
                change((), TInstr::return_call(target, new_args))
              } else {
                unchanged()
              }
            }
          None =>
            if processed != instr {
              change((), processed)
            } else {
              unchanged()
            }
        }
      }
      TInstrKind::TCallRef(type_idx, args, ref_) => {
        let old_type_abs = sp_typeidx_raw(type_idx)
        let removed = match removed_by_type_abs.get(old_type_abs) {
          Some(v) => v
          None =>
            return if processed != instr {
              change((), processed)
            } else {
              unchanged()
            }
        }
        let new_args = sp_filter_call_args(args, removed)
        let new_type_idx = match new_type_idx_by_old_abs.get(old_type_abs) {
          Some(v) => v
          None => type_idx
        }
        if new_args != args || new_type_idx != type_idx || processed != instr {
          change((), TInstr::call_ref(new_type_idx, new_args, ref_))
        } else {
          unchanged()
        }
      }
      TInstrKind::TReturnCallRef(type_idx, args, ref_) => {
        let old_type_abs = sp_typeidx_raw(type_idx)
        let removed = match removed_by_type_abs.get(old_type_abs) {
          Some(v) => v
          None =>
            return if processed != instr {
              change((), processed)
            } else {
              unchanged()
            }
        }
        let new_args = sp_filter_call_args(args, removed)
        let new_type_idx = match new_type_idx_by_old_abs.get(old_type_abs) {
          Some(v) => v
          None => type_idx
        }
        if new_args != args || new_type_idx != type_idx || processed != instr {
          change((), TInstr::return_call_ref(new_type_idx, new_args, ref_))
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
fn sp_collect_subtypes(
  rec_types : Array[RecType],
) -> (Array[SubType], Array[Int], Array[Array[Int]], Array[Bool]) {
  let subtypes : Array[SubType] = []
  let group_starts : Array[Int] = []
  let mut next = 0
  for rec in rec_types {
    match rec {
      SingleRecType(st) => {
        subtypes.push(st)
        group_starts.push(next)
        next += 1
      }
      GroupRecType(sts) => {
        let start = next
        for st in sts {
          subtypes.push(st)
          group_starts.push(start)
          next += 1
        }
      }
    }
  }
  let immediate_subs : Array[Array[Int]] = []
  let has_sig_super : Array[Bool] = []
  for _ in 0..<subtypes.length() {
    immediate_subs.push([])
    has_sig_super.push(false)
  }
  for i = 0; i < subtypes.length(); i = i + 1 {
    for super_idx in subtypes[i].super_types() {
      match sp_resolve_type_idx(super_idx, group_starts[i], subtypes.length()) {
        Some(super_abs) => {
          immediate_subs[super_abs].push(i)
          match subtypes[super_abs].get_comptype() {
            FuncCompType(_, _) => has_sig_super[i] = true
            _ => ()
          }
        }
        None => ()
      }
    }
  }
  (subtypes, group_starts, immediate_subs, has_sig_super)
}

///|
fn sp_run_iteration(mod : Module) -> (Module, Bool) {
  if mod.table_sec is Some(_) {
    return (mod, false)
  }
  let funcs = match mod.code_sec {
    Some(CodeSec(fs)) => fs
    None => return (mod, false)
  }
  let func_sec = match mod.func_sec {
    Some(FuncSec(type_idxs)) => type_idxs
    None => return (mod, false)
  }
  let type_recs = match mod.type_sec {
    Some(TypeSec(recs)) => recs.copy()
    None => return (mod, false)
  }
  if funcs.is_empty() || func_sec.is_empty() {
    return (mod, false)
  }
  let func_types = sp_collect_func_types(mod)
  let func_type_idxs = sp_collect_func_type_idxs(mod)
  let total_func_count = func_types.length()
  if total_func_count == 0 || func_type_idxs.length() != total_func_count {
    return (mod, false)
  }
  let import_func_count = sp_count_imported_funcs(mod)
  let total_types = sp_flattened_type_count(type_recs)
  if total_types == 0 {
    return (mod, false)
  }

  let funcs_by_type : Array[Array[Int]] = []
  let used_params_by_type : Array[Set[Int]] = []
  let calls_by_type : Array[Array[SPCallSite]] = []
  let optimizable_by_type : Array[Bool] = []
  for _ in 0..<total_types {
    funcs_by_type.push([])
    used_params_by_type.push(Set::new())
    calls_by_type.push([])
    optimizable_by_type.push(true)
  }

  let has_unseen_calls : Array[Bool] = Array::make(total_func_count, false)
  mark_exports_unseen(mod, has_unseen_calls)
  mark_start_unseen(mod, has_unseen_calls)
  mark_elem_unseen(mod, has_unseen_calls)

  for abs_idx = 0; abs_idx < total_func_count; abs_idx = abs_idx + 1 {
    let type_abs = sp_typeidx_raw(func_type_idxs[abs_idx])
    if type_abs < 0 || type_abs >= total_types {
      continue
    }
    funcs_by_type[type_abs].push(abs_idx)
    if abs_idx < import_func_count {
      optimizable_by_type[type_abs] = false
      continue
    }
    let def_idx = abs_idx - import_func_count
    if def_idx < 0 || def_idx >= funcs.length() {
      continue
    }
    let FuncType(params, _) = func_types[abs_idx]
    let param_count = params.length()
    let used = used_params_by_type[type_abs]
    match funcs[def_idx] {
      TFunc(_, body) => {
        let walker = ModuleTransformer::new().on_tinstruction_evt(fn(
          self,
          _,
          instr,
        ) {
          match instr.kind {
            TInstrKind::TLocalGet(LocalIdx(raw)) => {
              let idx = raw.reinterpret_as_int()
              if idx >= 0 && idx < param_count {
                used.add(idx)
              }
            }
            TInstrKind::TCall(target, args)
            | TInstrKind::TReturnCall(target, args) => {
              let FuncIdx(raw) = target
              let target_abs = raw.reinterpret_as_int()
              if target_abs >= 0 && target_abs < total_func_count {
                let callee_type_abs = sp_typeidx_raw(func_type_idxs[target_abs])
                if callee_type_abs >= 0 && callee_type_abs < total_types {
                  calls_by_type[callee_type_abs].push(sp_callsite(args.copy()))
                }
              }
            }
            TInstrKind::TCallRef(type_idx, args, _)
            | TInstrKind::TReturnCallRef(type_idx, args, _) => {
              let called_type_abs = sp_typeidx_raw(type_idx)
              if called_type_abs >= 0 && called_type_abs < total_types {
                calls_by_type[called_type_abs].push(sp_callsite(args.copy()))
              }
            }
            _ => ()
          }
          self.walk_tinstruction_default((), instr)
        })
        ignore(walker.walk_texpr((), body))
      }
      _ => ()
    }
  }

  for abs_idx = 0; abs_idx < total_func_count; abs_idx = abs_idx + 1 {
    if !has_unseen_calls[abs_idx] {
      continue
    }
    let type_abs = sp_typeidx_raw(func_type_idxs[abs_idx])
    if type_abs >= 0 && type_abs < total_types {
      optimizable_by_type[type_abs] = false
    }
  }

  match mod.tag_sec {
    Some(TagSec(tags)) =>
      for tag in tags {
        let TagType(type_idx) = tag
        let type_abs = sp_typeidx_raw(type_idx)
        if type_abs >= 0 && type_abs < total_types {
          optimizable_by_type[type_abs] = false
        }
      }
    None => ()
  }

  let (flat_subtypes, _, immediate_subs, has_sig_super) = sp_collect_subtypes(
    type_recs,
  )

  let removed_by_type_abs : Map[Int, Set[Int]] = Map::new()
  let removed_unused_by_type_abs : Map[Int, Set[Int]] = Map::new()
  let removed_const_by_type_abs : Map[Int, Map[Int, TInstr]] = Map::new()
  let new_type_idx_by_old_abs : Map[Int, TypeIdx] = Map::new()
  let new_type_recs = type_recs.copy()
  let mut flat_type_count = total_types

  for type_abs = 0; type_abs < total_types; type_abs = type_abs + 1 {
    if !optimizable_by_type[type_abs] {
      continue
    }
    if funcs_by_type[type_abs].is_empty() {
      continue
    }
    if !immediate_subs[type_abs].is_empty() || has_sig_super[type_abs] {
      continue
    }
    let old_sig = match flat_subtypes[type_abs].get_comptype() {
      FuncCompType(params, results) => FuncType::new(params, results)
      _ => continue
    }
    let FuncType(old_params, old_results) = old_sig
    let num_params = old_params.length()
    let calls = calls_by_type[type_abs]
    let used_params = used_params_by_type[type_abs]
    let removed_const : Map[Int, TInstr] = Map::new()
    for p = 0; p < num_params; p = p + 1 {
      if calls.is_empty() {
        continue
      }
      let mut candidate : TInstr? = None
      let mut all_const = true
      for callsite in calls {
        let args = callsite.args
        if p >= args.length() || !sp_is_literal_const(args[p]) {
          all_const = false
          break
        }
        match candidate {
          None => candidate = Some(args[p])
          Some(prev) =>
            if prev != args[p] {
              all_const = false
              break
            }
        }
      }
      if all_const {
        match candidate {
          Some(c) => removed_const.set(p, c)
          None => ()
        }
      }
    }
    let removed_unused : Set[Int] = Set::new()
    for p = 0; p < num_params; p = p + 1 {
      if removed_const.contains(p) {
        continue
      }
      if used_params.contains(p) {
        continue
      }
      if calls.is_empty() || sp_all_calls_arg_pure(calls, p) {
        removed_unused.add(p)
      }
    }
    let removed_all : Set[Int] = Set::new()
    for p = 0; p < num_params; p = p + 1 {
      if removed_unused.contains(p) || removed_const.contains(p) {
        removed_all.add(p)
      }
    }
    if removed_all.is_empty() {
      continue
    }
    let new_params : Array[ValType] = []
    for p = 0; p < num_params; p = p + 1 {
      if !removed_all.contains(p) {
        new_params.push(old_params[p])
      }
    }
    let new_type_idx = TypeIdx::new(flat_type_count.reinterpret_as_uint())
    flat_type_count += 1
    new_type_recs.push(sp_make_func_type(new_params, old_results))
    removed_by_type_abs.set(type_abs, removed_all)
    removed_unused_by_type_abs.set(type_abs, removed_unused)
    removed_const_by_type_abs.set(type_abs, removed_const)
    new_type_idx_by_old_abs.set(type_abs, new_type_idx)
  }

  if new_type_idx_by_old_abs.is_empty() {
    return (mod, false)
  }

  let new_func_type_idxs = func_sec.copy()
  for i = 0; i < new_func_type_idxs.length(); i = i + 1 {
    let abs_idx = import_func_count + i
    if abs_idx < 0 || abs_idx >= total_func_count {
      continue
    }
    let old_type_abs = sp_typeidx_raw(func_type_idxs[abs_idx])
    match new_type_idx_by_old_abs.get(old_type_abs) {
      Some(new_idx) => new_func_type_idxs[i] = new_idx
      None => ()
    }
  }

  let new_funcs : Array[Func] = []
  for i = 0; i < funcs.length(); i = i + 1 {
    let abs_idx = import_func_count + i
    if abs_idx < 0 || abs_idx >= total_func_count {
      new_funcs.push(funcs[i])
      continue
    }
    let old_type_abs = sp_typeidx_raw(func_type_idxs[abs_idx])
    let rewritten_func = match funcs[i] {
      TFunc(locals, body) => {
        let body_after_sig = match removed_by_type_abs.get(old_type_abs) {
          Some(_) => {
            let FuncType(old_params, _) = func_types[abs_idx]
            let removed_unused = match
              removed_unused_by_type_abs.get(old_type_abs) {
              Some(v) => v
              None => Set::new()
            }
            let removed_const = match
              removed_const_by_type_abs.get(old_type_abs) {
              Some(v) => v
              None => Map::new()
            }
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
              false,
            )
            let body2 = sp_rewrite_calls(
              body1, func_type_idxs, removed_by_type_abs, new_type_idx_by_old_abs,
            )
            let final_body = if prologue.is_empty() {
              body2
            } else {
              TExpr::new([..prologue, ..body2.instrs])
            }
            Func::t_func(new_locals, final_body)
          }
          None => {
            let body2 = sp_rewrite_calls(
              body, func_type_idxs, removed_by_type_abs, new_type_idx_by_old_abs,
            )
            Func::t_func(locals, body2)
          }
        }
        body_after_sig
      }
      _ => funcs[i]
    }
    new_funcs.push(rewritten_func)
  }

  let out_mod = mod
    .with_type_sec(TypeSec::new(new_type_recs))
    .with_func_sec(FuncSec::new(new_func_type_idxs))
    .with_code_sec(CodeSec::new(new_funcs))
  (out_mod, true)
}

///|
fn run_signature_pruning(mod : Module) -> Module {
  let (mod1, changed1) = sp_run_iteration(mod)
  if !changed1 {
    return mod
  }
  let (mod2, _) = sp_run_iteration(mod1)
  mod2
}

///|
fn signature_pruning_ir_pass(mod : Module) -> ModuleTransformer[IRContext] {
  let rewritten = run_signature_pruning(mod)
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
test "signature pruning removes unused params across same signature group" {
  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::drop(TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(9))])),
      TInstr::drop(TInstr::call(FuncIdx::new(2), [TInstr::i32_const(I32(11))])),
      TInstr::i32_const(I32(0)),
    ]),
  )
  let callee1 = Func::t_func([], TExpr::new([TInstr::i32_const(I32(7))]))
  let callee2 = Func::t_func([], TExpr::new([TInstr::i32_const(I32(8))]))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        sp_make_func_type([ValType::i32()], [ValType::i32()]),
        sp_make_func_type([], [ValType::i32()]),
      ]),
    )
    .with_func_sec(
      FuncSec::new([TypeIdx::new(1), TypeIdx::new(0), TypeIdx::new(0)]),
    )
    .with_code_sec(CodeSec::new([caller, callee1, callee2]))
  let pass = signature_pruning_ir_pass(mod)
  let optimized = match pass.walk_module(IRContext::new(), mod) {
    Ok(Some((_, m))) => m
    Ok(None) => mod
    Err(e) => fail("signature_pruning_ir_pass failed: \{e}")
  }
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, { instrs, .. }), _, _])) => {
      let call_args : Array[Int] = []
      for instr in instrs {
        match instr.kind {
          TInstrKind::TDrop({ kind: TInstrKind::TCall(FuncIdx(raw), args), .. }) => {
            let i = raw.reinterpret_as_int()
            if i == 1 || i == 2 {
              call_args.push(args.length())
            }
          }
          _ => ()
        }
      }
      call_args.sort()
      assert_eq(call_args, [0, 0])
    }
    _ => fail("expected rewritten caller body")
  }
  match optimized.func_sec {
    Some(FuncSec([_, t1, t2])) => {
      assert_true(t1 == t2)
      assert_true(t1 != TypeIdx::new(0))
    }
    _ => fail("expected rewritten function types")
  }
}

///|
test "signature pruning updates call_ref type and arguments" {
  let caller = Func::t_func(
    [],
    TExpr::new([
      TInstr::call_ref(
        TypeIdx::new(0),
        [TInstr::i32_const(I32(5))],
        TInstr::ref_func(FuncIdx::new(1)),
      ),
    ]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::i32_const(I32(7))]))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        sp_make_func_type([ValType::i32()], [ValType::i32()]),
        sp_make_func_type([], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1), TypeIdx::new(0)]))
    .with_code_sec(CodeSec::new([caller, callee]))
  let pass = signature_pruning_ir_pass(mod)
  let optimized = match pass.walk_module(IRContext::new(), mod) {
    Ok(Some((_, m))) => m
    Ok(None) => mod
    Err(e) => fail("signature_pruning_ir_pass failed: \{e}")
  }
  let mut seen = false
  match optimized.code_sec {
    Some(CodeSec([TFunc(_, { instrs, .. }), _])) =>
      for instr in instrs {
        match instr.kind {
          TInstrKind::TCallRef(type_idx, args, _) => {
            seen = true
            assert_eq(args.length(), 0)
            assert_true(type_idx != TypeIdx::new(0))
          }
          _ => ()
        }
      }
    _ => fail("expected rewritten caller")
  }
  assert_true(seen)
}

///|
test "signature pruning is disabled when table section is present" {
  let caller = Func::t_func(
    [],
    TExpr::new([TInstr::call(FuncIdx::new(1), [TInstr::i32_const(I32(9))])]),
  )
  let callee = Func::t_func([], TExpr::new([TInstr::i32_const(I32(7))]))
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        sp_make_func_type([ValType::i32()], [ValType::i32()]),
        sp_make_func_type([], [ValType::i32()]),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1), TypeIdx::new(0)]))
    .with_table_sec(
      TableSec::new([
        Table::new(
          TableType::new(
            RefType::new(true, HeapType::abs(AbsHeapType::func())),
            Limits::i32(1, None),
          ),
          Some(
            Expr::new([
              Instruction::ref_null(HeapType::abs(AbsHeapType::func())),
            ]),
          ),
        ),
      ]),
    )
    .with_code_sec(CodeSec::new([caller, callee]))
  let pass = signature_pruning_ir_pass(mod)
  let optimized = match pass.walk_module(IRContext::new(), mod) {
    Ok(Some((_, m))) => m
    Ok(None) => mod
    Err(e) => fail("signature_pruning_ir_pass failed: \{e}")
  }
  assert_eq(optimized, mod)
}
