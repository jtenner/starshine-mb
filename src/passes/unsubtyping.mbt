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
priv struct UFFlatTypes {
  subtypes : Array[SubType]
  group_starts : Array[Int]
  groups : Array[Array[Int]]
  type_to_group : Array[Int]
}

///|
priv struct UFTypeTree {
  parents : Array[Int?]
  children : Array[Array[Int]]
}

///|
fn uf_flatten_types(type_sec : TypeSec) -> UFFlatTypes {
  let TypeSec(recs) = type_sec
  let subtypes : Array[SubType] = []
  let group_starts : Array[Int] = []
  let groups : Array[Array[Int]] = []
  let type_to_group : Array[Int] = []
  let mut next = 0
  let mut group_idx = 0
  for rec in recs {
    match rec {
      SingleRecType(st) => {
        subtypes.push(st)
        group_starts.push(next)
        groups.push([next])
        type_to_group.push(group_idx)
        next += 1
      }
      GroupRecType(sts) => {
        let start = next
        let group : Array[Int] = []
        for st in sts {
          subtypes.push(st)
          group_starts.push(start)
          group.push(next)
          type_to_group.push(group_idx)
          next += 1
        }
        groups.push(group)
      }
    }
    group_idx += 1
  }
  { subtypes, group_starts, groups, type_to_group }
}

///|
fn uf_tree_new(size : Int) -> UFTypeTree {
  let parents : Array[Int?] = Array::make(size, None)
  let children : Array[Array[Int]] = []
  for _ in 0..<size {
    children.push([])
  }
  { parents, children }
}

///|
fn uf_tree_remove_child(
  children : Array[Array[Int]],
  parent : Int,
  child : Int,
) -> Unit {
  if parent < 0 || parent >= children.length() {
    return
  }
  let next_children : Array[Int] = []
  for existing in children[parent] {
    if existing != child {
      next_children.push(existing)
    }
  }
  children[parent] = next_children
}

///|
fn uf_tree_set_parent(tree : UFTypeTree, sub : Int, supertype : Int) -> Unit {
  match tree.parents[sub] {
    Some(old_parent) =>
      if old_parent == supertype {
        return
      } else {
        uf_tree_remove_child(tree.children, old_parent, sub)
      }
    None => ()
  }
  tree.parents[sub] = Some(supertype)
  tree.children[supertype].push(sub)
}

///|
fn uf_tree_supertypes(tree : UFTypeTree, idx : Int) -> Array[Int] {
  let out : Array[Int] = []
  let mut curr : Int? = Some(idx)
  while curr is Some(i) {
    out.push(i)
    curr = tree.parents[i]
  }
  out
}

///|
fn uf_tree_subtypes(tree : UFTypeTree, idx : Int) -> Array[Int] {
  let out : Array[Int] = []
  let stack : Array[Int] = [idx]
  while !stack.is_empty() {
    let curr = stack.pop().unwrap()
    out.push(curr)
    for child in tree.children[curr] {
      stack.push(child)
    }
  }
  out
}

///|
fn uf_resolve_type_idx(
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
fn uf_collect_valtype_refs(
  out : Array[Int],
  vt : ValType,
  group_start : Int,
  total : Int,
) -> Unit {
  match vt {
    RefTypeValType(rt) =>
      match rt {
        HeapTypeRefType(_, HeapType(type_idx)) =>
          match uf_resolve_type_idx(type_idx, group_start, total) {
            Some(idx) => out.push(idx)
            None => ()
          }
        _ => ()
      }
    _ => ()
  }
}

///|
fn uf_collect_storage_refs(
  out : Array[Int],
  st : StorageType,
  group_start : Int,
  total : Int,
) -> Unit {
  match st {
    ValTypeStorageType(vt) =>
      uf_collect_valtype_refs(out, vt, group_start, total)
    _ => ()
  }
}

///|
fn uf_collect_subtype_refs(
  subtype : SubType,
  group_start : Int,
  total : Int,
) -> Array[Int] {
  let out : Array[Int] = []
  for super_idx in subtype.super_types() {
    match uf_resolve_type_idx(super_idx, group_start, total) {
      Some(idx) => out.push(idx)
      None => ()
    }
  }
  match subtype.get_comptype() {
    FuncCompType(params, results) => {
      for p in params {
        uf_collect_valtype_refs(out, p, group_start, total)
      }
      for r in results {
        uf_collect_valtype_refs(out, r, group_start, total)
      }
    }
    StructCompType(fields) =>
      for field in fields {
        let FieldType(st, _) = field
        uf_collect_storage_refs(out, st, group_start, total)
      }
    ArrayCompType(field) => {
      let FieldType(st, _) = field
      uf_collect_storage_refs(out, st, group_start, total)
    }
  }
  out
}

///|
fn uf_collect_func_type_idx_by_func(mod : Module) -> Map[FuncIdx, TypeIdx] {
  let out : Map[FuncIdx, TypeIdx] = Map::new()
  let mut next : UInt = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(type_idx)) => {
            out[FuncIdx::new(next)] = type_idx
            next += 1
          }
          _ => ()
        }
      }
    None => ()
  }
  match mod.func_sec {
    Some(FuncSec(type_idxs)) =>
      for type_idx in type_idxs {
        out[FuncIdx::new(next)] = type_idx
        next += 1
      }
    None => ()
  }
  out
}

///|
fn uf_collect_all_global_types(mod : Module) -> Array[GlobalType] {
  let out : Array[GlobalType] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, GlobalExternType(global_type)) => out.push(global_type)
          _ => ()
        }
      }
    None => ()
  }
  match mod.global_sec {
    Some(GlobalSec(globals)) =>
      for global in globals {
        let Global(global_type, _) = global
        out.push(global_type)
      }
    None => ()
  }
  out
}

///|
fn uf_collect_all_table_types(mod : Module) -> Array[TableType] {
  let out : Array[TableType] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, TableExternType(table_type)) => out.push(table_type)
          _ => ()
        }
      }
    None => ()
  }
  match mod.table_sec {
    Some(TableSec(tables)) =>
      for table in tables {
        let Table(table_type, _) = table
        out.push(table_type)
      }
    None => ()
  }
  out
}

///|
fn uf_collect_all_tag_types(mod : Module) -> Array[TagType] {
  let out : Array[TagType] = []
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, TagExternType(tag_type)) => out.push(tag_type)
          _ => ()
        }
      }
    None => ()
  }
  match mod.tag_sec {
    Some(TagSec(tags)) =>
      for tag in tags {
        out.push(tag)
      }
    None => ()
  }
  out
}

///|
fn uf_mark_public_type(
  public_types : Set[Int],
  flat : UFFlatTypes,
  idx : Int,
) -> Unit {
  let stack : Array[Int] = [idx]
  while !stack.is_empty() {
    let curr = stack.pop().unwrap()
    if curr < 0 || curr >= flat.subtypes.length() || public_types.contains(curr) {
      continue
    }
    public_types.add(curr)
    for
      ref_ in uf_collect_subtype_refs(
        flat.subtypes[curr],
        flat.group_starts[curr],
        flat.subtypes.length(),
      ) {
      stack.push(ref_)
    }
  }
}

///|
fn uf_mark_public_valtype(
  public_types : Set[Int],
  flat : UFFlatTypes,
  vt : ValType,
) -> Unit {
  match vt {
    RefTypeValType(HeapTypeRefType(_, HeapType(type_idx))) =>
      match uf_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
        Some(idx) => uf_mark_public_type(public_types, flat, idx)
        None => ()
      }
    _ => ()
  }
}

///|
fn uf_mark_public_reftype(
  public_types : Set[Int],
  flat : UFFlatTypes,
  rt : RefType,
) -> Unit {
  match rt {
    HeapTypeRefType(_, HeapType(type_idx)) =>
      match uf_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
        Some(idx) => uf_mark_public_type(public_types, flat, idx)
        None => ()
      }
    _ => ()
  }
}

///|
fn uf_collect_public_types(mod : Module, flat : UFFlatTypes) -> Set[Int] {
  let public_types : Set[Int] = Set::new()
  let func_types = uf_collect_func_type_idx_by_func(mod)
  let global_types = uf_collect_all_global_types(mod)
  let table_types = uf_collect_all_table_types(mod)
  let tag_types = uf_collect_all_tag_types(mod)

  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(type_idx)) =>
            match uf_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
              Some(idx) => uf_mark_public_type(public_types, flat, idx)
              None => ()
            }
          Import(_, _, TagExternType(TagType(type_idx))) =>
            match uf_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
              Some(idx) => uf_mark_public_type(public_types, flat, idx)
              None => ()
            }
          Import(_, _, GlobalExternType(GlobalType(vt, _))) =>
            uf_mark_public_valtype(public_types, flat, vt)
          Import(_, _, TableExternType(TableType(rt, _))) =>
            uf_mark_public_reftype(public_types, flat, rt)
          _ => ()
        }
      }
    None => ()
  }

  match mod.export_sec {
    Some(ExportSec(exports)) =>
      for export_ in exports {
        let Export(_, extern_idx) = export_
        match extern_idx {
          FuncExternIdx(func_idx) =>
            match func_types.get(func_idx) {
              Some(type_idx) =>
                match uf_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
                  Some(idx) => uf_mark_public_type(public_types, flat, idx)
                  None => ()
                }
              None => ()
            }
          GlobalExternIdx(GlobalIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < global_types.length() {
              let GlobalType(vt, _) = global_types[idx]
              uf_mark_public_valtype(public_types, flat, vt)
            }
          }
          TableExternIdx(TableIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < table_types.length() {
              let TableType(rt, _) = table_types[idx]
              uf_mark_public_reftype(public_types, flat, rt)
            }
          }
          TagExternIdx(TagIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < tag_types.length() {
              let TagType(type_idx) = tag_types[idx]
              match uf_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
                Some(type_i) => uf_mark_public_type(public_types, flat, type_i)
                None => ()
              }
            }
          }
          _ => ()
        }
      }
    None => ()
  }

  let initially_public : Array[Int] = []
  for idx in public_types {
    initially_public.push(idx)
  }
  for idx in initially_public {
    let group_idx = flat.type_to_group[idx]
    for abs_idx in flat.groups[group_idx] {
      public_types.add(abs_idx)
    }
  }
  public_types
}

///|
fn uf_abs_to_typeidx(
  abs_idx : Int,
  group_start : Int,
  group_len : Int,
) -> TypeIdx {
  if abs_idx >= group_start && abs_idx < group_start + group_len {
    TypeIdx::rec((abs_idx - group_start).reinterpret_as_uint())
  } else {
    TypeIdx::new(abs_idx.reinterpret_as_uint())
  }
}

///|
fn uf_heap_type_abs(heap_type : HeapType, total : Int) -> Int? {
  match heap_type {
    HeapType(type_idx) => uf_resolve_type_idx(type_idx, 0, total)
    _ => None
  }
}

///|
fn uf_valtype_heap_abs(vt : ValType, total : Int) -> Int? {
  match vt {
    RefTypeValType(rt) => uf_heap_type_abs(rt.get_heap_type(), total)
    _ => None
  }
}

///|
fn uf_is_original_subtype(sub : Int, supertype : Int, env : Env) -> Bool {
  if sub == supertype {
    return true
  }
  Match::matches(
    HeapType::new(TypeIdx::new(sub.reinterpret_as_uint())),
    HeapType::new(TypeIdx::new(supertype.reinterpret_as_uint())),
    env,
  )
}

///|
fn uf_work_key(sub : Int, supertype : Int) -> String {
  sub.to_string() + ":" + supertype.to_string()
}

///|
fn uf_note_subtype(
  work : Array[(Int, Int)],
  seen : Set[String],
  sub : Int,
  supertype : Int,
) -> Unit {
  if sub == supertype {
    return
  }
  let key = uf_work_key(sub, supertype)
  if seen.contains(key) {
    return
  }
  seen.add(key)
  work.push((sub, supertype))
}

///|
fn uf_note_valtype_subtype(
  work : Array[(Int, Int)],
  seen : Set[String],
  sub : ValType,
  supertype : ValType,
  total : Int,
) -> Unit {
  match
    (uf_valtype_heap_abs(sub, total), uf_valtype_heap_abs(supertype, total)) {
    (Some(sub_idx), Some(super_idx)) =>
      uf_note_subtype(work, seen, sub_idx, super_idx)
    _ => ()
  }
}

///|
fn uf_note_storage_subtype(
  work : Array[(Int, Int)],
  seen : Set[String],
  sub : StorageType,
  supertype : StorageType,
  total : Int,
) -> Unit {
  match (sub, supertype) {
    (ValTypeStorageType(sub_vt), ValTypeStorageType(super_vt)) =>
      uf_note_valtype_subtype(work, seen, sub_vt, super_vt, total)
    _ => ()
  }
}

///|
fn uf_note_valtypes_subtype(
  work : Array[(Int, Int)],
  seen : Set[String],
  subs : Array[ValType],
  supers : Array[ValType],
  total_types : Int,
) -> Unit {
  let len = if subs.length() < supers.length() {
    subs.length()
  } else {
    supers.length()
  }
  for i = 0; i < len; i = i + 1 {
    uf_note_valtype_subtype(work, seen, subs[i], supers[i], total_types)
  }
}

///|
fn uf_label_types(env : Env, label : LabelIdx) -> Array[ValType] {
  match env.get_label_types(label) {
    Some(types) => types
    None => []
  }
}

///|
fn uf_catch_label_types(env : Env, label : LabelIdx) -> Array[ValType] {
  match env.get_catch_label_types(label) {
    Some(types) => types
    None => []
  }
}

///|
fn uf_catch_label(catch_ : Catch) -> LabelIdx {
  match catch_ {
    Catch(_, label)
    | CatchRef(_, label)
    | CatchAll(label)
    | CatchAllRef(label) => label
  }
}

///|
fn uf_catch_payload_types(catch_ : Catch, env : Env) -> Array[ValType] {
  let exnref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::exn())),
  )
  match catch_ {
    Catch(tag, _) =>
      match env.resolve_tag_functype(tag) {
        Some(FuncType(params, _)) => params.copy()
        None => []
      }
    CatchRef(tag, _) => {
      let payload = match env.resolve_tag_functype(tag) {
        Some(FuncType(params, _)) => params.copy()
        None => []
      }
      payload.push(exnref)
      payload
    }
    CatchAll(_) => []
    CatchAllRef(_) => [exnref]
  }
}

///|
fn uf_note_try_table_catch_subtypes(
  work : Array[(Int, Int)],
  seen : Set[String],
  catches : Array[Catch],
  env : Env,
  total_types : Int,
) -> Unit {
  for catch_ in catches {
    let payload = uf_catch_payload_types(catch_, env)
    let expected = uf_catch_label_types(env, uf_catch_label(catch_))
    uf_note_valtypes_subtype(work, seen, payload, expected, total_types)
  }
}

///|
fn uf_note_args_subtype(
  work : Array[(Int, Int)],
  seen : Set[String],
  args : Array[TInstr],
  expected : Array[ValType],
  env : Env,
  total_types : Int,
) -> Unit {
  for i = 0; i < args.length(); i = i + 1 {
    if i < expected.length() {
      match lcs_infer_tinstr_type(args[i], env) {
        Some(sub) =>
          uf_note_valtype_subtype(work, seen, sub, expected[i], total_types)
        None => ()
      }
    }
  }
}

///|
fn uf_infer_tinstr_result_types(instr : TInstr, env : Env) -> Array[ValType]? {
  match instr {
    TCall(target, _) =>
      match env.get_functype_by_funcidx(target) {
        Some(FuncType(_, results)) => Some(results)
        None => None
      }
    TCallIndirect(type_idx, _, _, _) | TCallRef(type_idx, _, _) =>
      match env.resolve_functype(type_idx) {
        Some(FuncType(_, results)) => Some(results)
        None => None
      }
    TBlock(bt, _) | TLoop(bt, _) | TIf(bt, _, _, _) | TTryTable(bt, _, _) =>
      match env.expand_blocktype(bt) {
        Ok((_, results)) => Some(results)
        Err(_) => None
      }
    _ =>
      match lcs_infer_tinstr_type(instr, env) {
        Some(vt) => Some([vt])
        None => None
      }
  }
}

///|
fn uf_infer_texpr_result_types(
  body : TExpr,
  expected_arity : Int,
  env : Env,
) -> Array[ValType]? {
  if expected_arity <= 0 {
    return Some([])
  }
  let { instrs, .. } = body
  if instrs.is_empty() {
    return None
  }
  let last = instrs[instrs.length() - 1]
  match uf_infer_tinstr_result_types(last, env) {
    Some(results) if results.length() == expected_arity => return Some(results)
    _ => ()
  }
  if instrs.length() < expected_arity {
    return None
  }
  let start = instrs.length() - expected_arity
  let out : Array[ValType] = []
  for i = start; i < instrs.length(); i = i + 1 {
    match lcs_infer_tinstr_type(instrs[i], env) {
      Some(vt) => out.push(vt)
      None => return None
    }
  }
  Some(out)
}

///|
fn uf_note_join_subtype(
  work : Array[(Int, Int)],
  seen : Set[String],
  body : TExpr,
  expected_results : Array[ValType],
  env : Env,
  total_types : Int,
) -> Unit {
  if expected_results.is_empty() {
    return
  }
  match uf_infer_texpr_result_types(body, expected_results.length(), env) {
    Some(sub_results) =>
      uf_note_valtypes_subtype(
        work, seen, sub_results, expected_results, total_types,
      )
    None => ()
  }
}

///|
fn uf_push_cast(casts : Map[Int, Array[Int]], src : Int, dst : Int) -> Unit {
  match casts.get(src) {
    Some(dsts) => {
      for existing in dsts {
        if existing == dst {
          return
        }
      }
      dsts.push(dst)
    }
    None => casts[src] = [dst]
  }
}

///|
fn uf_note_cast(
  work : Array[(Int, Int)],
  seen : Set[String],
  casts : Map[Int, Array[Int]],
  env : Env,
  src : Int,
  dst : Int,
  exact : Bool,
) -> Unit {
  if src == dst {
    return
  }
  if uf_is_original_subtype(dst, src, env) {
    if exact {
      uf_note_subtype(work, seen, dst, src)
      uf_push_cast(casts, src, dst)
      return
    }
    uf_push_cast(casts, src, dst)
    return
  }
  if uf_is_original_subtype(src, dst, env) {
    uf_note_subtype(work, seen, src, dst)
  }
}

///|
fn uf_note_instr_cast(
  work : Array[(Int, Int)],
  seen : Set[String],
  casts : Map[Int, Array[Int]],
  env : Env,
  src_heap : HeapType,
  dst_heap : HeapType,
  total : Int,
  exact : Bool,
) -> Unit {
  match (uf_heap_type_abs(src_heap, total), uf_heap_type_abs(dst_heap, total)) {
    (Some(src), Some(dst)) =>
      uf_note_cast(work, seen, casts, env, src, dst, exact)
    _ => ()
  }
}

///|
fn uf_note_indirect_call_barrier(
  work : Array[(Int, Int)],
  seen : Set[String],
  env : Env,
  type_idx : TypeIdx,
  total_types : Int,
) -> Unit {
  match uf_resolve_type_idx(type_idx, 0, total_types) {
    Some(target_abs) =>
      for sub = 0; sub < total_types; sub = sub + 1 {
        if sub != target_abs && uf_is_original_subtype(sub, target_abs, env) {
          uf_note_subtype(work, seen, sub, target_abs)
        }
      }
    None => ()
  }
}

///|
fn uf_collect_from_texpr(
  body : TExpr,
  env : Env,
  func_results : Array[ValType],
  total_types : Int,
  original_env : Env,
  work : Array[(Int, Int)],
  seen : Set[String],
  casts : Map[Int, Array[Int]],
  traps_never_happen : Bool,
) -> Unit {
  let { instrs, .. } = body
  for instr in instrs {
    uf_collect_from_tinstr(
      instr, env, func_results, total_types, original_env, work, seen, casts, traps_never_happen,
    )
  }
}

///|
fn uf_collect_from_tinstr(
  instr : TInstr,
  env : Env,
  func_results : Array[ValType],
  total_types : Int,
  original_env : Env,
  work : Array[(Int, Int)],
  seen : Set[String],
  casts : Map[Int, Array[Int]],
  traps_never_happen : Bool,
) -> Unit {
  match instr {
    TLocalSet(local_idx, value) | TLocalTee(local_idx, value) =>
      match (lcs_infer_tinstr_type(value, env), env.get_local_type(local_idx)) {
        (Some(sub), Some(supertype)) =>
          uf_note_valtype_subtype(work, seen, sub, supertype, total_types)
        _ => ()
      }
    TGlobalSet(global_idx, value) =>
      match
        (lcs_infer_tinstr_type(value, env), env.get_global_type(global_idx)) {
        (Some(sub), Some(GlobalType(supertype, _))) =>
          uf_note_valtype_subtype(work, seen, sub, supertype, total_types)
        _ => ()
      }
    TCall(target, args) | TReturnCall(target, args) =>
      match env.get_functype_by_funcidx(target) {
        Some(FuncType(params, _)) =>
          for i = 0; i < args.length(); i = i + 1 {
            if i < params.length() {
              match lcs_infer_tinstr_type(args[i], env) {
                Some(sub) =>
                  uf_note_valtype_subtype(
                    work,
                    seen,
                    sub,
                    params[i],
                    total_types,
                  )
                None => ()
              }
            }
          }
        None => ()
      }
    TCallIndirect(type_idx, _, args, _) | TCallRef(type_idx, args, _) =>
      match env.resolve_functype(type_idx) {
        Some(FuncType(params, _)) =>
          for i = 0; i < args.length(); i = i + 1 {
            if i < params.length() {
              match lcs_infer_tinstr_type(args[i], env) {
                Some(sub) =>
                  uf_note_valtype_subtype(
                    work,
                    seen,
                    sub,
                    params[i],
                    total_types,
                  )
                None => ()
              }
            }
          }
        None => ()
      }
    TReturnCallIndirect(type_idx, _, args, _)
    | TReturnCallRef(type_idx, args, _) =>
      match env.resolve_functype(type_idx) {
        Some(FuncType(params, _)) =>
          for i = 0; i < args.length(); i = i + 1 {
            if i < params.length() {
              match lcs_infer_tinstr_type(args[i], env) {
                Some(sub) =>
                  uf_note_valtype_subtype(
                    work,
                    seen,
                    sub,
                    params[i],
                    total_types,
                  )
                None => ()
              }
            }
          }
        None => ()
      }
    TReturn(values) =>
      for i = 0; i < values.length(); i = i + 1 {
        if i < func_results.length() {
          match lcs_infer_tinstr_type(values[i], env) {
            Some(sub) =>
              uf_note_valtype_subtype(
                work,
                seen,
                sub,
                func_results[i],
                total_types,
              )
            None => ()
          }
        }
      }
    TThrow(tag_idx, values) =>
      match env.resolve_tag_functype(tag_idx) {
        Some(FuncType(params, _)) =>
          for i = 0; i < values.length(); i = i + 1 {
            if i < params.length() {
              match lcs_infer_tinstr_type(values[i], env) {
                Some(sub) =>
                  uf_note_valtype_subtype(
                    work,
                    seen,
                    sub,
                    params[i],
                    total_types,
                  )
                None => ()
              }
            }
          }
        None => ()
      }
    TBr(label, args) =>
      uf_note_args_subtype(
        work,
        seen,
        args,
        uf_label_types(env, label),
        env,
        total_types,
      )
    TBrIf(label, _, args) =>
      uf_note_args_subtype(
        work,
        seen,
        args,
        uf_label_types(env, label),
        env,
        total_types,
      )
    TBrTable(labels, default_label, _, args) => {
      uf_note_args_subtype(
        work,
        seen,
        args,
        uf_label_types(env, default_label),
        env,
        total_types,
      )
      for label in labels {
        uf_note_args_subtype(
          work,
          seen,
          args,
          uf_label_types(env, label),
          env,
          total_types,
        )
      }
    }
    TStructSet(type_idx, field_idx, _, value) =>
      match env.resolve_struct_fields(type_idx) {
        Ok(fields) => {
          let U32(raw) = field_idx
          let idx = raw.reinterpret_as_int()
          if idx >= 0 && idx < fields.length() {
            let FieldType(storage, _) = fields[idx]
            match (lcs_infer_tinstr_type(value, env), storage) {
              (Some(sub), ValTypeStorageType(supertype)) =>
                uf_note_valtype_subtype(work, seen, sub, supertype, total_types)
              _ => ()
            }
          }
        }
        Err(_) => ()
      }
    TArraySet(type_idx, _, _, value) | TArrayFill(type_idx, _, _, value, _) =>
      match
        (env.resolve_array_field(type_idx), lcs_infer_tinstr_type(value, env)) {
        (Ok(FieldType(super_storage, _)), Some(sub)) =>
          match super_storage {
            ValTypeStorageType(supertype) =>
              uf_note_valtype_subtype(work, seen, sub, supertype, total_types)
            _ => ()
          }
        _ => ()
      }
    TRefCast(_, dst_heap, value) | TRefTest(_, dst_heap, value) =>
      match lcs_infer_tinstr_type(value, env) {
        Some(RefTypeValType(src_rt)) =>
          uf_note_instr_cast(
            work,
            seen,
            casts,
            original_env,
            src_rt.get_heap_type(),
            dst_heap,
            total_types,
            false,
          )
        _ => ()
      }
    TRefCastDescEq(_, dst_heap, value) | TRefTestDesc(_, dst_heap, value) =>
      match lcs_infer_tinstr_type(value, env) {
        Some(RefTypeValType(src_rt)) =>
          uf_note_instr_cast(
            work,
            seen,
            casts,
            original_env,
            src_rt.get_heap_type(),
            dst_heap,
            total_types,
            true,
          )
        _ => ()
      }
    TBrOnCast(_, _, src_heap, dst_heap, _, _)
    | TBrOnCastFail(_, _, src_heap, dst_heap, _, _) =>
      uf_note_instr_cast(
        work,
        seen,
        casts,
        original_env,
        src_heap,
        dst_heap,
        total_types,
        src_heap == dst_heap,
      )
    TBlock(bt, body) =>
      match env.expand_blocktype(bt) {
        Ok((_, results)) => {
          let nested_env = env.with_label(results)
          uf_collect_from_texpr(
            body, nested_env, func_results, total_types, original_env, work, seen,
            casts, traps_never_happen,
          )
          uf_note_join_subtype(
            work, seen, body, results, nested_env, total_types,
          )
        }
        Err(_) =>
          uf_collect_from_texpr(
            body, env, func_results, total_types, original_env, work, seen, casts,
            traps_never_happen,
          )
      }
    TLoop(bt, body) =>
      match env.expand_blocktype(bt) {
        Ok((params, results)) => {
          let nested_env = env.with_label(params)
          uf_collect_from_texpr(
            body, nested_env, func_results, total_types, original_env, work, seen,
            casts, traps_never_happen,
          )
          uf_note_join_subtype(
            work, seen, body, results, nested_env, total_types,
          )
        }
        Err(_) =>
          uf_collect_from_texpr(
            body, env, func_results, total_types, original_env, work, seen, casts,
            traps_never_happen,
          )
      }
    TIf(bt, cond, then_body, else_body) => {
      uf_collect_from_tinstr(
        cond, env, func_results, total_types, original_env, work, seen, casts, traps_never_happen,
      )
      match env.expand_blocktype(bt) {
        Ok((_, results)) => {
          let nested_env = env.with_label(results)
          uf_collect_from_texpr(
            then_body, nested_env, func_results, total_types, original_env, work,
            seen, casts, traps_never_happen,
          )
          uf_note_join_subtype(
            work, seen, then_body, results, nested_env, total_types,
          )
          match else_body {
            Some(else_expr) => {
              uf_collect_from_texpr(
                else_expr, nested_env, func_results, total_types, original_env, work,
                seen, casts, traps_never_happen,
              )
              uf_note_join_subtype(
                work, seen, else_expr, results, nested_env, total_types,
              )
            }
            None => ()
          }
        }
        Err(_) => {
          uf_collect_from_texpr(
            then_body, env, func_results, total_types, original_env, work, seen,
            casts, traps_never_happen,
          )
          match else_body {
            Some(else_expr) =>
              uf_collect_from_texpr(
                else_expr, env, func_results, total_types, original_env, work, seen,
                casts, traps_never_happen,
              )
            None => ()
          }
        }
      }
    }
    TTryTable(bt, catches, body) =>
      match env.expand_blocktype(bt) {
        Ok((_, results)) => {
          let nested_env = env.with_label(results)
          uf_collect_from_texpr(
            body, nested_env, func_results, total_types, original_env, work, seen,
            casts, traps_never_happen,
          )
          uf_note_join_subtype(
            work, seen, body, results, nested_env, total_types,
          )
          uf_note_try_table_catch_subtypes(
            work, seen, catches, nested_env, total_types,
          )
        }
        Err(_) =>
          uf_collect_from_texpr(
            body, env, func_results, total_types, original_env, work, seen, casts,
            traps_never_happen,
          )
      }
    _ => ()
  }

  if !traps_never_happen {
    match instr {
      TCallIndirect(type_idx, _, _, _)
      | TReturnCallIndirect(type_idx, _, _, _) =>
        uf_note_indirect_call_barrier(
          work, seen, original_env, type_idx, total_types,
        )
      _ => ()
    }
  }

  for child in tg_eval_children(instr) {
    uf_collect_from_tinstr(
      child, env, func_results, total_types, original_env, work, seen, casts, traps_never_happen,
    )
  }
}

///|
fn uf_count_imported_funcs(mod : Module) -> UInt {
  let mut count : UInt = 0
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn uf_collect_initial_requirements(
  mod : Module,
  flat : UFFlatTypes,
  public_types : Set[Int],
  work : Array[(Int, Int)],
  seen : Set[String],
  casts : Map[Int, Array[Int]],
  traps_never_happen : Bool,
) -> Unit {
  let total_types = flat.subtypes.length()
  for type_abs in public_types {
    match flat.subtypes[type_abs] {
      SubType(_, supers, _) =>
        for super_idx in supers {
          match
            uf_resolve_type_idx(
              super_idx,
              flat.group_starts[type_abs],
              total_types,
            ) {
            Some(super_abs) => uf_note_subtype(work, seen, type_abs, super_abs)
            None => ()
          }
        }
      CompTypeSubType(_) => ()
    }
  }

  let env = Env::new().with_module(mod)
  let imported_funcs = uf_count_imported_funcs(mod)
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for i = 0; i < funcs.length(); i = i + 1 {
        let global_func_idx = FuncIdx::new(
          imported_funcs + i.reinterpret_as_uint(),
        )
        let (params, results) = match
          env.get_functype_by_funcidx(global_func_idx) {
          Some(FuncType(params, results)) => (params, results)
          None => ([], [])
        }
        match funcs[i] {
          TFunc(locals, body) => {
            let all_locals = params.copy()
            for local_ty in locals {
              all_locals.push(local_ty)
            }
            let func_env = env
              .with_locals(all_locals)
              .with_labels([results])
              .with_return_type(Some(results))
            let { instrs, .. } = body
            for instr in instrs {
              uf_collect_from_tinstr(
                instr, func_env, results, total_types, env, work, seen, casts, traps_never_happen,
              )
            }
          }
          Func(locals, body) => {
            let all_locals = params.copy()
            let expanded = match expand_locals(locals) {
              Ok(vts) => vts
              Err(_) => []
            }
            for local_ty in expanded {
              all_locals.push(local_ty)
            }
            let func_env = env
              .with_locals(all_locals)
              .with_labels([results])
              .with_return_type(Some(results))
            match to_texpr(body, func_env) {
              Ok({ instrs, .. }) =>
                for instr in instrs {
                  uf_collect_from_tinstr(
                    instr, func_env, results, total_types, env, work, seen, casts,
                    traps_never_happen,
                  )
                }
              Err(_) => ()
            }
          }
        }
      }
    None => ()
  }

  match mod.global_sec {
    Some(GlobalSec(globals)) =>
      for global in globals {
        let Global(_, init) = global
        match to_texpr(init, env.with_locals([]).with_return_type(Some([]))) {
          Ok({ instrs, .. }) =>
            for instr in instrs {
              uf_collect_from_tinstr(
                instr,
                env,
                [],
                total_types,
                env,
                work,
                seen,
                casts,
                traps_never_happen,
              )
            }
          Err(_) => ()
        }
      }
    None => ()
  }
}

///|
fn uf_process_definitions(
  sub : Int,
  supertype : Int,
  flat : UFFlatTypes,
  work : Array[(Int, Int)],
  seen : Set[String],
) -> Unit {
  let sub_ct = flat.subtypes[sub].get_comptype()
  let super_ct = flat.subtypes[supertype].get_comptype()
  let total = flat.subtypes.length()
  match (sub_ct, super_ct) {
    (
      FuncCompType(sub_params, sub_results),
      FuncCompType(super_params, super_results),
    ) => {
      let param_len = if sub_params.length() < super_params.length() {
        sub_params.length()
      } else {
        super_params.length()
      }
      for i = 0; i < param_len; i = i + 1 {
        uf_note_valtype_subtype(
          work,
          seen,
          super_params[i],
          sub_params[i],
          total,
        )
      }
      let result_len = if sub_results.length() < super_results.length() {
        sub_results.length()
      } else {
        super_results.length()
      }
      for i = 0; i < result_len; i = i + 1 {
        uf_note_valtype_subtype(
          work,
          seen,
          sub_results[i],
          super_results[i],
          total,
        )
      }
    }
    (StructCompType(sub_fields), StructCompType(super_fields)) => {
      let field_len = if sub_fields.length() < super_fields.length() {
        sub_fields.length()
      } else {
        super_fields.length()
      }
      for i = 0; i < field_len; i = i + 1 {
        let FieldType(sub_storage, _) = sub_fields[i]
        let FieldType(super_storage, _) = super_fields[i]
        uf_note_storage_subtype(work, seen, sub_storage, super_storage, total)
      }
    }
    (
      ArrayCompType(FieldType(sub_storage, _)),
      ArrayCompType(FieldType(super_storage, _)),
    ) => uf_note_storage_subtype(work, seen, sub_storage, super_storage, total)
    _ => ()
  }
}

///|
fn uf_process_casts(
  sub : Int,
  supertype : Int,
  old_super : Int?,
  tree : UFTypeTree,
  casts : Map[Int, Array[Int]],
  env : Env,
  work : Array[(Int, Int)],
  seen : Set[String],
) -> Unit {
  for type_abs in uf_tree_subtypes(tree, sub) {
    for src in uf_tree_supertypes(tree, supertype) {
      match old_super {
        Some(old) if src == old => break
        _ => ()
      }
      match casts.get(src) {
        Some(dsts) =>
          for dst in dsts {
            if uf_is_original_subtype(type_abs, dst, env) {
              uf_note_subtype(work, seen, type_abs, dst)
            }
          }
        None => ()
      }
    }
  }
}

///|
fn uf_process_subtype(
  sub : Int,
  supertype : Int,
  flat : UFFlatTypes,
  env : Env,
  tree : UFTypeTree,
  casts : Map[Int, Array[Int]],
  work : Array[(Int, Int)],
  seen : Set[String],
) -> Unit {
  if !uf_is_original_subtype(sub, supertype, env) {
    return
  }
  let old_super = tree.parents[sub]
  match old_super {
    Some(old) => {
      if supertype == old {
        return
      }
      if uf_is_original_subtype(old, supertype, env) {
        uf_note_subtype(work, seen, old, supertype)
        return
      }
      uf_process_subtype(supertype, old, flat, env, tree, casts, work, seen)
    }
    None => ()
  }

  uf_tree_set_parent(tree, sub, supertype)
  uf_process_definitions(sub, supertype, flat, work, seen)
  uf_process_casts(sub, supertype, old_super, tree, casts, env, work, seen)
}

///|
fn uf_rewrite_types(
  mod : Module,
  flat : UFFlatTypes,
  tree : UFTypeTree,
  public_types : Set[Int],
) -> Result[Module, String] {
  let next_subtypes = flat.subtypes.copy()
  let mut changed = false
  for idx = 0; idx < next_subtypes.length(); idx = idx + 1 {
    if public_types.contains(idx) {
      continue
    }
    let group_idx = flat.type_to_group[idx]
    let group_start = flat.group_starts[idx]
    let group_len = flat.groups[group_idx].length()
    let next_super = match tree.parents[idx] {
      Some(parent_abs) =>
        [uf_abs_to_typeidx(parent_abs, group_start, group_len)]
      None => []
    }
    let rewritten = match next_subtypes[idx] {
      SubType(final_, _, ct) => SubType::new(final_, next_super, ct)
      CompTypeSubType(ct) =>
        if next_super.is_empty() {
          SubType::comp_type(ct)
        } else {
          SubType::new(false, next_super, ct)
        }
    }
    if rewritten != next_subtypes[idx] {
      next_subtypes[idx] = rewritten
      changed = true
    }
  }
  if !changed {
    return Ok(mod)
  }
  let recs : Array[RecType] = []
  for group in flat.groups {
    let next_group : Array[SubType] = []
    for abs_idx in group {
      next_group.push(next_subtypes[abs_idx])
    }
    if next_group.length() == 1 {
      recs.push(RecType::new(next_group[0]))
    } else {
      recs.push(RecType::group(next_group))
    }
  }
  let out = mod.with_type_sec(TypeSec::new(recs))
  match validate_module(out) {
    Ok(_) => Ok(out)
    Err(e) => Err("unsubtyping produced invalid module: \{e}")
  }
}

///|
fn unsubtyping(
  mod : Module,
  traps_never_happen? : Bool = false,
) -> Result[Module, String] {
  let type_sec = match mod.type_sec {
    Some(sec) => sec
    None => return Ok(mod)
  }
  let flat = uf_flatten_types(type_sec)
  if flat.subtypes.is_empty() {
    return Ok(mod)
  }
  let public_types = uf_collect_public_types(mod, flat)
  let work : Array[(Int, Int)] = []
  let seen : Set[String] = Set::new()
  let casts : Map[Int, Array[Int]] = Map::new()
  uf_collect_initial_requirements(
    mod, flat, public_types, work, seen, casts, traps_never_happen,
  )

  let tree = uf_tree_new(flat.subtypes.length())
  let env = Env::new().with_module(mod)
  while !work.is_empty() {
    let (sub, supertype) = work.pop().unwrap()
    uf_process_subtype(sub, supertype, flat, env, tree, casts, work, seen)
  }

  uf_rewrite_types(mod, flat, tree, public_types)
}

///|
fn uf_test_flatten_subtypes(mod : Module) -> Array[SubType] {
  let out : Array[SubType] = []
  match mod.type_sec {
    Some(TypeSec(recs)) =>
      for rec in recs {
        match rec {
          SingleRecType(st) => out.push(st)
          GroupRecType(sts) =>
            for st in sts {
              out.push(st)
            }
        }
      }
    None => ()
  }
  out
}

///|
fn uf_test_subtype_at(mod : Module, idx : Int) -> SubType {
  let flat = uf_test_flatten_subtypes(mod)
  if idx < 0 || idx >= flat.length() {
    abort("type index out of bounds in test helper")
  }
  flat[idx]
}

///|
fn uf_test_direct_super(mod : Module, idx : Int) -> TypeIdx? {
  match uf_test_subtype_at(mod, idx) {
    SubType(_, supers, _) if supers.length() == 1 => Some(supers[0])
    _ => None
  }
}

///|
fn uf_test_chain_module(with_cast : Bool) -> Module {
  let top = single_rec_type(sub_type(false, [], struct_comp_type([])))
  let mid = single_rec_type(
    sub_type(false, [TypeIdx::new(0)], struct_comp_type([])),
  )
  let bot = single_rec_type(
    sub_type(false, [TypeIdx::new(1)], struct_comp_type([])),
  )
  let func_ty = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let body : Array[TInstr] = [
    TInstr::local_set(LocalIdx::new(0), TInstr::struct_new(TypeIdx::new(2), [])),
  ]
  if with_cast {
    body.push(
      TInstr::drop(
        TInstr::ref_cast(
          false,
          HeapType::new(TypeIdx::new(1)),
          TInstr::local_get(LocalIdx::new(0)),
        ),
      ),
    )
  }
  Module::new()
  .with_type_sec(TypeSec::new([top, mid, bot, func_ty]))
  .with_func_sec(FuncSec::new([TypeIdx::new(3)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::ref_null(HeapType::new(TypeIdx::new(0)))],
        TExpr::new(body),
      ),
    ]),
  )
}

///|
fn uf_test_descriptor_exact_chain_module(
  use_cast_desc_eq : Bool,
  typed_body : Bool,
) -> Module {
  let top = single_rec_type(sub_type(false, [], struct_comp_type([])))
  let mid = single_rec_type(
    sub_type(false, [TypeIdx::new(0)], struct_comp_type([])),
  )
  let bot = single_rec_type(
    sub_type(false, [TypeIdx::new(1)], struct_comp_type([])),
  )
  let func_ty = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let local_top = ValType::ref_null(HeapType::new(TypeIdx::new(0)))
  let func = if typed_body {
    let body : Array[TInstr] = [
      TInstr::local_set(
        LocalIdx::new(0),
        TInstr::struct_new(TypeIdx::new(2), []),
      ),
    ]
    if use_cast_desc_eq {
      body.push(
        TInstr::drop(
          TInstr::ref_cast_desc_eq(
            false,
            HeapType::new(TypeIdx::new(1)),
            TInstr::local_get(LocalIdx::new(0)),
          ),
        ),
      )
    } else {
      body.push(
        TInstr::drop(
          TInstr::ref_test_desc(
            false,
            HeapType::new(TypeIdx::new(1)),
            TInstr::local_get(LocalIdx::new(0)),
          ),
        ),
      )
    }
    Func::t_func([local_top], TExpr::new(body))
  } else {
    let body : Array[Instruction] = [
      Instruction::struct_new(TypeIdx::new(2)),
      Instruction::local_set(LocalIdx::new(0)),
      Instruction::local_get(LocalIdx::new(0)),
    ]
    if use_cast_desc_eq {
      body.push(
        Instruction::ref_cast_desc_eq(true, HeapType::new(TypeIdx::new(1))),
      )
    } else {
      body.push(
        Instruction::ref_test_desc(true, HeapType::new(TypeIdx::new(1))),
      )
    }
    body.push(Instruction::drop())
    Func::new([Locals::new(1, local_top)], Expr::new(body))
  }
  Module::new()
  .with_type_sec(TypeSec::new([top, mid, bot, func_ty]))
  .with_func_sec(FuncSec::new([TypeIdx::new(3)]))
  .with_code_sec(CodeSec::new([func]))
}

///|
fn uf_test_public_super_module() -> Module {
  let top = single_rec_type(sub_type(false, [], struct_comp_type([])))
  let sub = single_rec_type(
    sub_type(false, [TypeIdx::new(0)], struct_comp_type([])),
  )
  let func_ty = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  Module::new()
  .with_type_sec(TypeSec::new([top, sub, func_ty]))
  .with_func_sec(FuncSec::new([TypeIdx::new(2)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::ref_null(HeapType::new(TypeIdx::new(0)))],
        TExpr::new([
          TInstr::local_set(
            LocalIdx::new(0),
            TInstr::struct_new(TypeIdx::new(1), []),
          ),
        ]),
      ),
    ]),
  )
  .with_global_sec(
    GlobalSec::new([
      Global::new(
        GlobalType::new(
          ValType::ref_null(HeapType::new(TypeIdx::new(1))),
          false,
        ),
        Expr::new([Instruction::ref_null(HeapType::new(TypeIdx::new(1)))]),
      ),
    ]),
  )
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::new("pub"), ExternIdx::global(GlobalIdx::new(0))),
    ]),
  )
}

///|
fn uf_test_mid_ref_block_type() -> BlockType {
  BlockType::val_type(ValType::ref_null(HeapType::new(TypeIdx::new(1))))
}

///|
fn uf_test_control_flow_constraint_module(body : Array[TInstr]) -> Module {
  let top = single_rec_type(sub_type(false, [], struct_comp_type([])))
  let mid = single_rec_type(
    sub_type(false, [TypeIdx::new(0)], struct_comp_type([])),
  )
  let bot = single_rec_type(
    sub_type(false, [TypeIdx::new(1)], struct_comp_type([])),
  )
  let main_type = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  Module::new()
  .with_type_sec(TypeSec::new([top, mid, bot, main_type]))
  .with_func_sec(FuncSec::new([TypeIdx::new(3)]))
  .with_code_sec(CodeSec::new([Func::t_func([], TExpr::new(body))]))
}

///|
fn uf_assert_unsubtyping_preserves_mid_edge(mod : Module) -> Unit {
  let out = match unsubtyping(mod) {
    Ok(m) => m
    Err(e) => abort("unexpected unsubtyping error: \{e}")
  }
  if uf_test_direct_super(out, 2) != Some(TypeIdx::new(1)) {
    abort("expected unsubtyping to preserve direct super edge 2 -> 1")
  }
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      abort(
        "expected control-flow constrained unsubtyping output to validate: \{e}",
      )
  }
}

///|
fn uf_test_try_table_catch_label_constraint_module() -> Module {
  let top = single_rec_type(sub_type(false, [], struct_comp_type([])))
  let mid = single_rec_type(
    sub_type(false, [TypeIdx::new(0)], struct_comp_type([])),
  )
  let bot = single_rec_type(
    sub_type(false, [TypeIdx::new(1)], struct_comp_type([])),
  )
  let tag_type = single_rec_type(
    comp_type_sub_type(
      func_comp_type([ValType::ref_null(HeapType::new(TypeIdx::new(1)))], []),
    ),
  )
  let main_type = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  Module::new()
  .with_type_sec(TypeSec::new([top, mid, bot, tag_type, main_type]))
  .with_func_sec(FuncSec::new([TypeIdx::new(4)]))
  .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(3))]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::drop(
            TInstr::try_table(
              BlockType::val_type(
                ValType::ref_null(HeapType::new(TypeIdx::new(1))),
              ),
              [Catch::new(TagIdx::new(0), LabelIdx::new(0))],
              TExpr::new([
                TInstr::throw_(TagIdx::new(0), [
                  TInstr::struct_new(TypeIdx::new(2), []),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    ]),
  )
}

///|
fn uf_test_try_table_outer_catch_target_constraint_module() -> Module {
  let top = single_rec_type(sub_type(false, [], struct_comp_type([])))
  let mid = single_rec_type(
    sub_type(false, [TypeIdx::new(0)], struct_comp_type([])),
  )
  let bot = single_rec_type(
    sub_type(false, [TypeIdx::new(1)], struct_comp_type([])),
  )
  let tag_type = single_rec_type(
    comp_type_sub_type(
      func_comp_type([ValType::ref_null(HeapType::new(TypeIdx::new(2)))], []),
    ),
  )
  let main_type = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  Module::new()
  .with_type_sec(TypeSec::new([top, mid, bot, tag_type, main_type]))
  .with_func_sec(FuncSec::new([TypeIdx::new(4)]))
  .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(3))]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::drop(
            TInstr::block(
              BlockType::val_type(
                ValType::ref_null(HeapType::new(TypeIdx::new(1))),
              ),
              TExpr::new([
                TInstr::try_table(
                  BlockType::void_(),
                  [Catch::new(TagIdx::new(0), LabelIdx::new(1))],
                  TExpr::new([
                    TInstr::throw_(TagIdx::new(0), [
                      TInstr::struct_new(TypeIdx::new(2), []),
                    ]),
                  ]),
                ),
                TInstr::ref_null(HeapType::new(TypeIdx::new(1))),
              ]),
            ),
          ),
        ]),
      ),
    ]),
  )
}

///|
fn uf_test_try_table_catch_ref_payload_constraint_module() -> Module {
  let tag_type = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i64()], [])),
  )
  let exnref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::exn())),
  )
  let main_type = single_rec_type(
    comp_type_sub_type(func_comp_type([], [ValType::i64(), exnref])),
  )
  Module::new()
  .with_type_sec(TypeSec::new([tag_type, main_type]))
  .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
  .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(0))]))
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
    ]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::try_table(
            BlockType::type_idx(TypeIdx::new(1)),
            [Catch::ref_(TagIdx::new(0), LabelIdx::new(1))],
            TExpr::new([
              TInstr::throw_(TagIdx::new(0), [TInstr::i64_const(I64(9L))]),
            ]),
          ),
        ]),
      ),
    ]),
  )
}

///|
fn uf_test_try_table_catch_ref_to_try_label_module() -> Module {
  let tag_type = single_rec_type(
    comp_type_sub_type(func_comp_type([ValType::i64()], [])),
  )
  let exnref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::exn())),
  )
  let main_type = single_rec_type(
    comp_type_sub_type(func_comp_type([], [ValType::i64(), exnref])),
  )
  Module::new()
  .with_type_sec(TypeSec::new([tag_type, main_type]))
  .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
  .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(0))]))
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
    ]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::try_table(
            BlockType::type_idx(TypeIdx::new(1)),
            [Catch::ref_(TagIdx::new(0), LabelIdx::new(0))],
            TExpr::new([
              TInstr::throw_(TagIdx::new(0), [TInstr::i64_const(I64(11L))]),
            ]),
          ),
        ]),
      ),
    ]),
  )
}

///|
fn uf_test_try_table_catch_all_ref_module() -> Module {
  let tag_type = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let exnref = ValType::ref_type(
    RefType::new(false, HeapType::abs(AbsHeapType::exn())),
  )
  let main_type = single_rec_type(
    comp_type_sub_type(func_comp_type([], [exnref])),
  )
  Module::new()
  .with_type_sec(TypeSec::new([tag_type, main_type]))
  .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
  .with_tag_sec(TagSec::new([TagType::new(TypeIdx::new(0))]))
  .with_export_sec(
    ExportSec::new([
      Export::new(Name::new("main"), ExternIdx::func(FuncIdx::new(0))),
    ]),
  )
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::try_table(
            BlockType::type_idx(TypeIdx::new(1)),
            [Catch::all_ref(LabelIdx::new(0))],
            TExpr::new([TInstr::throw_(TagIdx::new(0), [])]),
          ),
        ]),
      ),
    ]),
  )
}

///|
fn uf_test_function_label_branch_constraint_module(use_br_if : Bool) -> Module {
  let top = single_rec_type(sub_type(false, [], struct_comp_type([])))
  let mid = single_rec_type(
    sub_type(false, [TypeIdx::new(0)], struct_comp_type([])),
  )
  let bot = single_rec_type(
    sub_type(false, [TypeIdx::new(1)], struct_comp_type([])),
  )
  let main_type = single_rec_type(
    comp_type_sub_type(
      func_comp_type([], [ValType::ref_null(HeapType::new(TypeIdx::new(1)))]),
    ),
  )
  let body = if use_br_if {
    TExpr::new([
      TInstr::block(
        BlockType::void_(),
        TExpr::new([
          TInstr::br_if(LabelIdx::new(1), TInstr::i32_const(I32(1)), [
            TInstr::struct_new(TypeIdx::new(2), []),
          ]),
          TInstr::nop(),
        ]),
      ),
      TInstr::ref_null(HeapType::new(TypeIdx::new(1))),
    ])
  } else {
    TExpr::new([
      TInstr::block(
        BlockType::void_(),
        TExpr::new([
          TInstr::br(LabelIdx::new(1), [TInstr::struct_new(TypeIdx::new(2), [])]),
          TInstr::nop(),
        ]),
      ),
      TInstr::ref_null(HeapType::new(TypeIdx::new(1))),
    ])
  }
  Module::new()
  .with_type_sec(TypeSec::new([top, mid, bot, main_type]))
  .with_func_sec(FuncSec::new([TypeIdx::new(3)]))
  .with_code_sec(CodeSec::new([Func::t_func([], body)]))
}

///|
fn uf_test_multivalue_join_constraint_module(join_instr : TInstr) -> Module {
  let top = single_rec_type(sub_type(false, [], struct_comp_type([])))
  let mid = single_rec_type(
    sub_type(false, [TypeIdx::new(0)], struct_comp_type([])),
  )
  let bot = single_rec_type(
    sub_type(false, [TypeIdx::new(1)], struct_comp_type([])),
  )
  let pair_type = single_rec_type(
    comp_type_sub_type(
      func_comp_type([], [
        ValType::ref_null(HeapType::new(TypeIdx::new(1))),
        ValType::i32(),
      ]),
    ),
  )
  let main_type = single_rec_type(
    comp_type_sub_type(
      func_comp_type([], [
        ValType::ref_null(HeapType::new(TypeIdx::new(1))),
        ValType::i32(),
      ]),
    ),
  )
  Module::new()
  .with_type_sec(TypeSec::new([top, mid, bot, pair_type, main_type]))
  .with_func_sec(FuncSec::new([TypeIdx::new(4)]))
  .with_code_sec(
    CodeSec::new([Func::t_func([], TExpr::new([TInstr::return_([join_instr])]))]),
  )
}

///|
fn uf_test_indirect_call_barrier_module(
  use_return_call_indirect : Bool,
) -> Module {
  let top = single_rec_type(sub_type(false, [], func_comp_type([], [])))
  let mid = single_rec_type(
    sub_type(false, [TypeIdx::new(0)], func_comp_type([], [])),
  )
  let bot = single_rec_type(
    sub_type(false, [TypeIdx::new(1)], func_comp_type([], [])),
  )
  let main_type = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let body : Array[TInstr] = [
    TInstr::local_set(
      LocalIdx::new(0),
      TInstr::ref_null(HeapType::new(TypeIdx::new(2))),
    ),
  ]
  if use_return_call_indirect {
    body.push(
      TInstr::return_call_indirect(
        TypeIdx::new(1),
        TableIdx::new(0),
        [],
        TInstr::i32_const(I32(0)),
      ),
    )
  } else {
    body.push(
      TInstr::call_indirect(
        TypeIdx::new(1),
        TableIdx::new(0),
        [],
        TInstr::i32_const(I32(0)),
      ),
    )
  }
  Module::new()
  .with_type_sec(TypeSec::new([top, mid, bot, main_type]))
  .with_func_sec(FuncSec::new([TypeIdx::new(3), TypeIdx::new(2)]))
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
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [ValType::ref_null(HeapType::new(TypeIdx::new(0)))],
        TExpr::new(body),
      ),
      Func::t_func([], TExpr::new([TInstr::nop()])),
    ]),
  )
}

///|
fn uf_test_run_unsubtyping_with_traps(
  mod : Module,
  traps_never_happen : Bool,
) -> Module {
  match unsubtyping(mod, traps_never_happen~) {
    Ok(out) => out
    Err(e) => abort("unexpected unsubtyping error: \{e}")
  }
}

///|
test "unsubtyping drops unneeded intermediate private supertype edge" {
  let mod = uf_test_chain_module(false)
  let out = match unsubtyping(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected unsubtyping error: \{e}")
  }
  assert_eq(uf_test_direct_super(out, 2), Some(TypeIdx::new(0)))
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("expected unsubtyping output to validate: \{e}")
  }
}

///|
test "unsubtyping preserves cast-observed subtype relation" {
  let mod = uf_test_chain_module(true)
  let out = match unsubtyping(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected unsubtyping error: \{e}")
  }
  let env = Env::new().with_module(out)
  assert_true(
    Match::matches(
      HeapType::new(TypeIdx::new(2)),
      HeapType::new(TypeIdx::new(1)),
      env,
    ),
  )
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("expected cast-preserving output to validate: \{e}")
  }
}

///|
test "unsubtyping preserves descriptor-exact subtype edge for typed ref.test_desc with super-typed source" {
  let mod = uf_test_descriptor_exact_chain_module(false, true)
  uf_assert_unsubtyping_preserves_mid_edge(mod)
}

///|
test "unsubtyping preserves descriptor-exact subtype edge for typed ref.cast_desc_eq with super-typed source" {
  let mod = uf_test_descriptor_exact_chain_module(true, true)
  uf_assert_unsubtyping_preserves_mid_edge(mod)
}

///|
test "unsubtyping preserves descriptor-exact subtype edge for untyped ref.test_desc with super-typed source" {
  let mod = uf_test_descriptor_exact_chain_module(false, false)
  match validate_module(mod) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected untyped descriptor ref.test_desc fixture to validate: \{e}",
      )
  }
  uf_assert_unsubtyping_preserves_mid_edge(mod)
}

///|
test "unsubtyping preserves descriptor-exact subtype edge for untyped ref.cast_desc_eq with super-typed source" {
  let mod = uf_test_descriptor_exact_chain_module(true, false)
  match validate_module(mod) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected untyped descriptor ref.cast_desc_eq fixture to validate: \{e}",
      )
  }
  uf_assert_unsubtyping_preserves_mid_edge(mod)
}

///|
test "unsubtyping keeps public supertypes unchanged" {
  let mod = uf_test_public_super_module()
  let out = match unsubtyping(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected unsubtyping error: \{e}")
  }
  assert_eq(uf_test_direct_super(out, 1), Some(TypeIdx::new(0)))
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("expected public-safe output to validate: \{e}")
  }
}

///|
test "unsubtyping preserves subtype edge required by br label flow" {
  let bt = uf_test_mid_ref_block_type()
  let mod = uf_test_control_flow_constraint_module([
    TInstr::drop(
      TInstr::block(
        bt,
        TExpr::new([
          TInstr::br(LabelIdx::new(0), [TInstr::struct_new(TypeIdx::new(2), [])]),
          TInstr::ref_null(HeapType::new(TypeIdx::new(1))),
        ]),
      ),
    ),
  ])
  uf_assert_unsubtyping_preserves_mid_edge(mod)
}

///|
test "unsubtyping preserves subtype edge required by br_if label flow" {
  let bt = uf_test_mid_ref_block_type()
  let mod = uf_test_control_flow_constraint_module([
    TInstr::drop(
      TInstr::block(
        bt,
        TExpr::new([
          TInstr::br_if(LabelIdx::new(0), TInstr::i32_const(I32(1)), [
            TInstr::struct_new(TypeIdx::new(2), []),
          ]),
          TInstr::ref_null(HeapType::new(TypeIdx::new(1))),
        ]),
      ),
    ),
  ])
  uf_assert_unsubtyping_preserves_mid_edge(mod)
}

///|
test "unsubtyping preserves subtype edge required by implicit function-label br flow" {
  let mod = uf_test_function_label_branch_constraint_module(false)
  match validate_module(mod) {
    Ok(_) => ()
    Err(e) => fail("expected br fixture module to validate: \{e}")
  }
  uf_assert_unsubtyping_preserves_mid_edge(mod)
}

///|
test "unsubtyping preserves subtype edge required by implicit function-label br_if flow" {
  let mod = uf_test_function_label_branch_constraint_module(true)
  match validate_module(mod) {
    Ok(_) => ()
    Err(e) => fail("expected br_if fixture module to validate: \{e}")
  }
  uf_assert_unsubtyping_preserves_mid_edge(mod)
}

///|
test "unsubtyping preserves subtype edge required by try_table catch-to-try-label flow" {
  let mod = uf_test_try_table_catch_label_constraint_module()
  match validate_module(mod) {
    Ok(_) => ()
    Err(e) => fail("expected try_table catch fixture module to validate: \{e}")
  }
  uf_assert_unsubtyping_preserves_mid_edge(mod)
}

///|
test "unsubtyping preserves subtype edge required by try_table catch-target label flow" {
  let mod = uf_test_try_table_outer_catch_target_constraint_module()
  match validate_module(mod) {
    Ok(_) => ()
    Err(e) =>
      fail("expected try_table outer catch fixture module to validate: \{e}")
  }
  uf_assert_unsubtyping_preserves_mid_edge(mod)
}

///|
test "unsubtyping preserves try_table catch_ref payload plus exnref flow validity" {
  let mod = uf_test_try_table_catch_ref_payload_constraint_module()
  match validate_module(mod) {
    Ok(_) => ()
    Err(e) =>
      fail("expected try_table catch_ref fixture module to validate: \{e}")
  }
  let out = match unsubtyping(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected unsubtyping error: \{e}")
  }
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected catch_ref payload plus exnref unsubtyping output to remain validator-clean: \{e}",
      )
  }
}

///|
test "unsubtyping catch_ref analysis does not mutate input module type signatures" {
  let mod = uf_test_try_table_catch_ref_payload_constraint_module()
  match validate_module(mod) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected catch_ref fixture module to validate before unsubtyping: \{e}",
      )
  }
  ignore(unsubtyping(mod))
  match validate_module(mod) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected catch_ref fixture module to remain validator-clean after unsubtyping analysis: \{e}",
      )
  }
}

///|
test "unsubtyping preserves try_table catch_ref to try-label payload plus exnref flow validity" {
  let mod = uf_test_try_table_catch_ref_to_try_label_module()
  match validate_module(mod) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected try_table catch_ref-to-try-label fixture module to validate: \{e}",
      )
  }
  let out = match unsubtyping(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected unsubtyping error: \{e}")
  }
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected catch_ref-to-try-label unsubtyping output to remain validator-clean: \{e}",
      )
  }
}

///|
test "unsubtyping preserves try_table catch_all_ref exnref flow validity" {
  let mod = uf_test_try_table_catch_all_ref_module()
  match validate_module(mod) {
    Ok(_) => ()
    Err(e) =>
      fail("expected try_table catch_all_ref fixture module to validate: \{e}")
  }
  let out = match unsubtyping(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected unsubtyping error: \{e}")
  }
  match validate_module(out) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected catch_all_ref unsubtyping output to remain validator-clean: \{e}",
      )
  }
}

///|
test "unsubtyping preserves subtype edge required by br_table label flow" {
  let bt = uf_test_mid_ref_block_type()
  let mod = uf_test_control_flow_constraint_module([
    TInstr::drop(
      TInstr::block(
        bt,
        TExpr::new([
          TInstr::block(
            bt,
            TExpr::new([
              TInstr::br_table(
                [LabelIdx::new(0)],
                LabelIdx::new(1),
                TInstr::i32_const(I32(0)),
                [TInstr::struct_new(TypeIdx::new(2), [])],
              ),
              TInstr::ref_null(HeapType::new(TypeIdx::new(1))),
            ]),
          ),
          TInstr::ref_null(HeapType::new(TypeIdx::new(1))),
        ]),
      ),
    ),
  ])
  uf_assert_unsubtyping_preserves_mid_edge(mod)
}

///|
test "unsubtyping preserves subtype edge required by multi-value typed block join" {
  let join_type_idx = TypeIdx::new(3)
  let mod = uf_test_multivalue_join_constraint_module(
    TInstr::block(
      BlockType::type_idx(join_type_idx),
      TExpr::new([
        TInstr::struct_new(TypeIdx::new(2), []),
        TInstr::i32_const(I32(9)),
      ]),
    ),
  )
  match validate_module(mod) {
    Ok(_) => ()
    Err(e) => fail("expected multivalue block fixture module to validate: \{e}")
  }
  uf_assert_unsubtyping_preserves_mid_edge(mod)
}

///|
test "unsubtyping preserves subtype edge required by multi-value typed loop join" {
  let join_type_idx = TypeIdx::new(3)
  let mod = uf_test_multivalue_join_constraint_module(
    TInstr::loop_(
      BlockType::type_idx(join_type_idx),
      TExpr::new([
        TInstr::struct_new(TypeIdx::new(2), []),
        TInstr::i32_const(I32(10)),
      ]),
    ),
  )
  match validate_module(mod) {
    Ok(_) => ()
    Err(e) => fail("expected multivalue loop fixture module to validate: \{e}")
  }
  uf_assert_unsubtyping_preserves_mid_edge(mod)
}

///|
test "unsubtyping preserves subtype edge required by multi-value typed if join" {
  let join_type_idx = TypeIdx::new(3)
  let mod = uf_test_multivalue_join_constraint_module(
    TInstr::if_(
      BlockType::type_idx(join_type_idx),
      TInstr::i32_const(I32(1)),
      TExpr::new([
        TInstr::struct_new(TypeIdx::new(2), []),
        TInstr::i32_const(I32(11)),
      ]),
      Some(
        TExpr::new([
          TInstr::ref_null(HeapType::new(TypeIdx::new(1))),
          TInstr::i32_const(I32(12)),
        ]),
      ),
    ),
  )
  match validate_module(mod) {
    Ok(_) => ()
    Err(e) => fail("expected multivalue if fixture module to validate: \{e}")
  }
  uf_assert_unsubtyping_preserves_mid_edge(mod)
}

///|
test "unsubtyping preserves subtype edge required by typed block join" {
  let bt = uf_test_mid_ref_block_type()
  let mod = uf_test_control_flow_constraint_module([
    TInstr::drop(
      TInstr::block(bt, TExpr::new([TInstr::struct_new(TypeIdx::new(2), [])])),
    ),
  ])
  uf_assert_unsubtyping_preserves_mid_edge(mod)
}

///|
test "unsubtyping preserves subtype edge required by typed loop join" {
  let bt = uf_test_mid_ref_block_type()
  let mod = uf_test_control_flow_constraint_module([
    TInstr::drop(
      TInstr::loop_(bt, TExpr::new([TInstr::struct_new(TypeIdx::new(2), [])])),
    ),
  ])
  uf_assert_unsubtyping_preserves_mid_edge(mod)
}

///|
test "unsubtyping preserves subtype edge required by typed if join" {
  let bt = uf_test_mid_ref_block_type()
  let mod = uf_test_control_flow_constraint_module([
    TInstr::drop(
      TInstr::if_(
        bt,
        TInstr::i32_const(I32(1)),
        TExpr::new([TInstr::struct_new(TypeIdx::new(2), [])]),
        Some(TExpr::new([TInstr::ref_null(HeapType::new(TypeIdx::new(1)))])),
      ),
    ),
  ])
  uf_assert_unsubtyping_preserves_mid_edge(mod)
}

///|
test "unsubtyping treats call_indirect cast barrier as trap-mode sensitive" {
  let mod = uf_test_indirect_call_barrier_module(false)

  let out_default = uf_test_run_unsubtyping_with_traps(mod, false)
  assert_eq(uf_test_direct_super(out_default, 2), Some(TypeIdx::new(1)))
  match validate_module(out_default) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected trap-sensitive call_indirect unsubtyping output to validate: \{e}",
      )
  }

  let out_tnh = uf_test_run_unsubtyping_with_traps(mod, true)
  assert_eq(uf_test_direct_super(out_tnh, 2), Some(TypeIdx::new(0)))
  match validate_module(out_tnh) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected traps-never-happen call_indirect unsubtyping output to validate: \{e}",
      )
  }
}

///|
test "unsubtyping treats return_call_indirect cast barrier as trap-mode sensitive" {
  let mod = uf_test_indirect_call_barrier_module(true)

  let out_default = uf_test_run_unsubtyping_with_traps(mod, false)
  assert_eq(uf_test_direct_super(out_default, 2), Some(TypeIdx::new(1)))
  match validate_module(out_default) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected trap-sensitive return_call_indirect unsubtyping output to validate: \{e}",
      )
  }

  let out_tnh = uf_test_run_unsubtyping_with_traps(mod, true)
  assert_eq(uf_test_direct_super(out_tnh, 2), Some(TypeIdx::new(0)))
  match validate_module(out_tnh) {
    Ok(_) => ()
    Err(e) =>
      fail(
        "expected traps-never-happen return_call_indirect unsubtyping output to validate: \{e}",
      )
  }
}
