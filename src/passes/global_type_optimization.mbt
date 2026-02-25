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
let gto_removed_field = -1

///|
priv struct GTOFieldInfo {
  has_write : Bool
  has_read : Bool
}

///|
priv struct GTOFlatTypes {
  subtypes : Array[SubType]
  group_starts : Array[Int]
  struct_fields : Array[Array[FieldType]?]
  supers : Array[Array[Int]]
  children : Array[Array[Int]]
}

///|
fn gto_empty_field_info() -> GTOFieldInfo {
  { has_write: false, has_read: false }
}

///|
fn gto_make_field_info_vec(n : Int) -> Array[GTOFieldInfo] {
  let out : Array[GTOFieldInfo] = []
  for _ in 0..<n {
    out.push(gto_empty_field_info())
  }
  out
}

///|
fn gto_copy_field_infos(
  infos : Array[Array[GTOFieldInfo]],
) -> Array[Array[GTOFieldInfo]] {
  let out : Array[Array[GTOFieldInfo]] = []
  for vec in infos {
    out.push(vec.copy())
  }
  out
}

///|
fn gto_typeidx_raw_int(type_idx : TypeIdx) -> Int {
  match type_idx {
    TypeIdx(i) => i.reinterpret_as_int()
    RecIdx(i) => i.reinterpret_as_int()
  }
}

///|
fn gto_u32_to_int(i : @lib.U32) -> Int {
  let @lib.U32(raw) = i
  raw.reinterpret_as_int()
}

///|
fn gto_resolve_type_idx(
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
fn gto_flatten_types(type_sec : TypeSec) -> GTOFlatTypes {
  let TypeSec(recs) = type_sec
  let subtypes : Array[SubType] = []
  let group_starts : Array[Int] = []
  let mut next = 0
  for rec in recs {
    match rec {
      SingleRecType(st) => {
        subtypes.push(st)
        group_starts.push(next)
        next += 1
      }
      GroupRecType(sts) => {
        let group_start = next
        for st in sts {
          subtypes.push(st)
          group_starts.push(group_start)
          next += 1
        }
      }
    }
  }
  let struct_fields : Array[Array[FieldType]?] = []
  for st in subtypes {
    match st.get_comptype() {
      StructCompType(fields) => struct_fields.push(Some(fields))
      _ => struct_fields.push(None)
    }
  }
  let supers : Array[Array[Int]] = []
  for i in 0..<subtypes.length() {
    let curr : Array[Int] = []
    for super_tidx in subtypes[i].super_types() {
      match
        gto_resolve_type_idx(super_tidx, group_starts[i], subtypes.length()) {
        Some(idx) => curr.push(idx)
        None => ()
      }
    }
    supers.push(curr)
  }
  let children : Array[Array[Int]] = []
  for _ in 0..<subtypes.length() {
    children.push([])
  }
  for child in 0..<supers.length() {
    for super_idx in supers[child] {
      if super_idx >= 0 && super_idx < children.length() {
        children[super_idx].push(child)
      }
    }
  }
  { subtypes, group_starts, struct_fields, supers, children }
}

///|
fn gto_supertypes_first_order(flat : GTOFlatTypes) -> Array[Int] {
  let n = flat.subtypes.length()
  let indegree = Array::make(n, 0)
  for i in 0..<n {
    indegree[i] = flat.supers[i].length()
  }
  let queue : Array[Int] = []
  for i in 0..<n {
    if indegree[i] == 0 {
      queue.push(i)
    }
  }
  let out : Array[Int] = []
  let mut qi = 0
  while qi < queue.length() {
    let curr = queue[qi]
    qi += 1
    out.push(curr)
    for child in flat.children[curr] {
      indegree[child] = indegree[child] - 1
      if indegree[child] == 0 {
        queue.push(child)
      }
    }
  }
  if out.length() < n {
    for i in 0..<n {
      let mut found = false
      for seen in out {
        if seen == i {
          found = true
          break
        }
      }
      if !found {
        out.push(i)
      }
    }
  }
  out
}

///|
fn gto_rebuild_type_sec(
  old_type_sec : TypeSec,
  subtypes : Array[SubType],
) -> TypeSec {
  let TypeSec(old_recs) = old_type_sec
  let new_recs : Array[RecType] = []
  let mut cursor = 0
  for rec in old_recs {
    match rec {
      SingleRecType(_) => {
        new_recs.push(RecType::new(subtypes[cursor]))
        cursor += 1
      }
      GroupRecType(sts) => {
        let next_group : Array[SubType] = []
        for _ in 0..<sts.length() {
          next_group.push(subtypes[cursor])
          cursor += 1
        }
        new_recs.push(RecType::group(next_group))
      }
    }
  }
  TypeSec::new(new_recs)
}

///|
fn gto_combine_field_info(
  dst : GTOFieldInfo,
  src : GTOFieldInfo,
) -> (GTOFieldInfo, Bool) {
  let mut out = dst
  let mut changed = false
  if !out.has_write && src.has_write {
    out = { ..out, has_write: true }
    changed = true
  }
  if !out.has_read && src.has_read {
    out = { ..out, has_read: true }
    changed = true
  }
  (out, changed)
}

///|
fn gto_combine_field_info_vec(
  dst : Array[GTOFieldInfo],
  src : Array[GTOFieldInfo],
) -> Bool {
  let mut changed = false
  let len = if dst.length() < src.length() {
    dst.length()
  } else {
    src.length()
  }
  for i in 0..<len {
    let (next, did_change) = gto_combine_field_info(dst[i], src[i])
    if did_change {
      dst[i] = next
      changed = true
    }
  }
  changed
}

///|
fn gto_note_write(
  infos : Array[Array[GTOFieldInfo]],
  type_idx : TypeIdx,
  field_idx : @lib.U32,
) -> Unit {
  let ti = gto_typeidx_raw_int(type_idx)
  if ti < 0 || ti >= infos.length() {
    return
  }
  let fi = gto_u32_to_int(field_idx)
  if fi < 0 || fi >= infos[ti].length() {
    return
  }
  let info = infos[ti][fi]
  if !info.has_write {
    infos[ti][fi] = { ..info, has_write: true }
  }
}

///|
fn gto_note_read(
  infos : Array[Array[GTOFieldInfo]],
  type_idx : TypeIdx,
  field_idx : @lib.U32,
) -> Unit {
  let ti = gto_typeidx_raw_int(type_idx)
  if ti < 0 || ti >= infos.length() {
    return
  }
  let fi = gto_u32_to_int(field_idx)
  if fi < 0 || fi >= infos[ti].length() {
    return
  }
  let info = infos[ti][fi]
  if !info.has_read {
    infos[ti][fi] = { ..info, has_read: true }
  }
}

///|
fn gto_scan_texpr(texpr : TExpr, infos : Array[Array[GTOFieldInfo]]) -> Unit {
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    match instr {
      TStructSet(type_idx, field_idx, _, _) =>
        gto_note_write(infos, type_idx, field_idx)
      TStructGet(type_idx, field_idx, _)
      | TStructGetS(type_idx, field_idx, _)
      | TStructGetU(type_idx, field_idx, _) =>
        gto_note_read(infos, type_idx, field_idx)
      _ => ()
    }
    self.walk_tinstruction_default((), instr)
  })
  ignore(walker.walk_texpr((), texpr))
}

///|
fn gto_scan_expr(
  expr : Expr,
  env : Env,
  infos : Array[Array[GTOFieldInfo]],
) -> Unit {
  match to_texpr(expr, env) {
    Ok(texpr) => gto_scan_texpr(texpr, infos)
    Err(_) => ()
  }
}

///|
fn gto_expand_locals(locals : Array[Locals]) -> Array[ValType]? {
  match expand_locals(locals) {
    Ok(ls) => Some(ls)
    Err(_) => None
  }
}

///|
fn gto_scan_module_uses(
  mod : Module,
  env : Env,
  infos : Array[Array[GTOFieldInfo]],
) -> Unit {
  match mod.code_sec {
    Some(CodeSec(funcs)) =>
      for func in funcs {
        match func {
          TFunc(_, body) => gto_scan_texpr(body, infos)
          Func(locals, body) =>
            match gto_expand_locals(locals) {
              Some(expanded) => {
                let local_env = env.with_locals(expanded)
                gto_scan_expr(body, local_env, infos)
              }
              None => ()
            }
        }
      }
    None => ()
  }
  match mod.global_sec {
    Some(GlobalSec(globals)) =>
      for global in globals {
        let Global(_, init) = global
        gto_scan_expr(init, env, infos)
      }
    None => ()
  }
  match mod.table_sec {
    Some(TableSec(tables)) =>
      for table in tables {
        let Table(_, init_expr) = table
        match init_expr {
          Some(expr) => gto_scan_expr(expr, env, infos)
          None => ()
        }
      }
    None => ()
  }
  match mod.elem_sec {
    Some(ElemSec(elems)) =>
      for elem in elems {
        let Elem(mode, kind) = elem
        match mode {
          Active(_, offset) => gto_scan_expr(offset, env, infos)
          _ => ()
        }
        match kind {
          FuncExprsElemKind(exprs) | TypedExprsElemKind(_, exprs) =>
            for expr in exprs {
              gto_scan_expr(expr, env, infos)
            }
          _ => ()
        }
      }
    None => ()
  }
  match mod.data_sec {
    Some(DataSec(datas)) =>
      for data in datas {
        let Data(mode, _) = data
        match mode {
          Active(_, offset) => gto_scan_expr(offset, env, infos)
          _ => ()
        }
      }
    None => ()
  }
}

///|
fn gto_propagate_to_super_and_subs(
  infos : Array[Array[GTOFieldInfo]],
  flat : GTOFlatTypes,
) -> Unit {
  let mut changed = true
  while changed {
    changed = false
    for child in 0..<flat.supers.length() {
      for super_idx in flat.supers[child] {
        if super_idx < 0 || super_idx >= infos.length() {
          continue
        }
        if gto_combine_field_info_vec(infos[super_idx], infos[child]) {
          changed = true
        }
        if gto_combine_field_info_vec(infos[child], infos[super_idx]) {
          changed = true
        }
      }
    }
  }
}

///|
fn gto_propagate_to_subs(
  infos : Array[Array[GTOFieldInfo]],
  flat : GTOFlatTypes,
) -> Unit {
  let order = gto_supertypes_first_order(flat)
  for super_idx in order {
    for child in flat.children[super_idx] {
      ignore(gto_combine_field_info_vec(infos[child], infos[super_idx]))
    }
  }
}

///|
fn gto_collect_func_type_idx_by_func(mod : Module) -> Map[FuncIdx, TypeIdx] {
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
fn gto_collect_all_global_types(mod : Module) -> Array[GlobalType] {
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
fn gto_collect_all_table_types(mod : Module) -> Array[TableType] {
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
fn gto_collect_all_tag_types(mod : Module) -> Array[TagType] {
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
fn gto_mark_public_heaptype(
  public_types : Set[Int],
  flat : GTOFlatTypes,
  group_start : Int,
  ht : HeapType,
) -> Unit {
  match ht {
    HeapType(tidx) =>
      match gto_resolve_type_idx(tidx, group_start, flat.subtypes.length()) {
        Some(idx) => gto_mark_public_type_idx(public_types, flat, idx)
        None => ()
      }
    _ => ()
  }
}

///|
fn gto_mark_public_reftype(
  public_types : Set[Int],
  flat : GTOFlatTypes,
  group_start : Int,
  rt : RefType,
) -> Unit {
  match rt {
    HeapTypeRefType(_, ht) =>
      gto_mark_public_heaptype(public_types, flat, group_start, ht)
    _ => ()
  }
}

///|
fn gto_mark_public_valtype(
  public_types : Set[Int],
  flat : GTOFlatTypes,
  group_start : Int,
  vt : ValType,
) -> Unit {
  match vt {
    RefTypeValType(rt) =>
      gto_mark_public_reftype(public_types, flat, group_start, rt)
    _ => ()
  }
}

///|
fn gto_mark_public_storage_type(
  public_types : Set[Int],
  flat : GTOFlatTypes,
  group_start : Int,
  st : StorageType,
) -> Unit {
  match st {
    ValTypeStorageType(vt) =>
      gto_mark_public_valtype(public_types, flat, group_start, vt)
    _ => ()
  }
}

///|
fn gto_mark_public_type_idx(
  public_types : Set[Int],
  flat : GTOFlatTypes,
  idx : Int,
) -> Unit {
  if idx < 0 || idx >= flat.subtypes.length() || public_types.contains(idx) {
    return
  }
  public_types.add(idx)
  for super_idx in flat.supers[idx] {
    gto_mark_public_type_idx(public_types, flat, super_idx)
  }
  let subtype = flat.subtypes[idx]
  let group_start = flat.group_starts[idx]
  match subtype.get_comptype() {
    FuncCompType(params, results) => {
      for p in params {
        gto_mark_public_valtype(public_types, flat, group_start, p)
      }
      for r in results {
        gto_mark_public_valtype(public_types, flat, group_start, r)
      }
    }
    StructCompType(fields) =>
      for field in fields {
        let FieldType(st, _) = field
        gto_mark_public_storage_type(public_types, flat, group_start, st)
      }
    ArrayCompType(field) => {
      let FieldType(st, _) = field
      gto_mark_public_storage_type(public_types, flat, group_start, st)
    }
  }
}

///|
fn gto_collect_public_types(mod : Module, flat : GTOFlatTypes) -> Set[Int] {
  let public_types : Set[Int] = Set::new()
  let func_types = gto_collect_func_type_idx_by_func(mod)
  let global_types = gto_collect_all_global_types(mod)
  let table_types = gto_collect_all_table_types(mod)
  let tag_types = gto_collect_all_tag_types(mod)
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(type_idx)) =>
            match gto_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
              Some(idx) => gto_mark_public_type_idx(public_types, flat, idx)
              None => ()
            }
          Import(_, _, TagExternType(TagType(type_idx))) =>
            match gto_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
              Some(idx) => gto_mark_public_type_idx(public_types, flat, idx)
              None => ()
            }
          Import(_, _, GlobalExternType(GlobalType(vt, _))) =>
            gto_mark_public_valtype(public_types, flat, 0, vt)
          Import(_, _, TableExternType(TableType(rt, _))) =>
            gto_mark_public_reftype(public_types, flat, 0, rt)
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
                match
                  gto_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
                  Some(idx) => gto_mark_public_type_idx(public_types, flat, idx)
                  None => ()
                }
              None => ()
            }
          GlobalExternIdx(GlobalIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < global_types.length() {
              let GlobalType(vt, _) = global_types[idx]
              gto_mark_public_valtype(public_types, flat, 0, vt)
            }
          }
          TableExternIdx(TableIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < table_types.length() {
              let TableType(rt, _) = table_types[idx]
              gto_mark_public_reftype(public_types, flat, 0, rt)
            }
          }
          TagExternIdx(TagIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < tag_types.length() {
              let TagType(type_idx) = tag_types[idx]
              match gto_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
                Some(type_i) =>
                  gto_mark_public_type_idx(public_types, flat, type_i)
                None => ()
              }
            }
          }
          _ => ()
        }
      }
    None => ()
  }
  public_types
}

///|
fn gto_identity_indexes(n : Int) -> Array[Int] {
  let out : Array[Int] = []
  for i in 0..<n {
    out.push(i)
  }
  out
}

///|
fn gto_count_removed(indexes : Array[Int]) -> Int {
  let mut removed = 0
  for idx in indexes {
    if idx == gto_removed_field {
      removed += 1
    }
  }
  removed
}

///|
fn gto_mark_can_become_immutable(
  can_become_immutable : Map[Int, Array[Bool]],
  type_idx : Int,
  field_idx : Int,
) -> Unit {
  match can_become_immutable.get(type_idx) {
    Some(vec) => {
      while vec.length() <= field_idx {
        vec.push(false)
      }
      vec[field_idx] = true
    }
    None => {
      let vec : Array[Bool] = []
      for _ in 0..<(field_idx + 1) {
        vec.push(false)
      }
      vec[field_idx] = true
      can_become_immutable[type_idx] = vec
    }
  }
}

///|
fn gto_super_field_can_be_immutable(
  flat : GTOFlatTypes,
  can_become_immutable : Map[Int, Array[Bool]],
  super_idx : Int,
  field_idx : Int,
) -> Bool {
  match flat.struct_fields[super_idx] {
    None => true
    Some(fields) => {
      if field_idx >= fields.length() {
        return true
      }
      if !fields[field_idx].is_mutable() {
        return true
      }
      match can_become_immutable.get(super_idx) {
        Some(vec) => field_idx < vec.length() && vec[field_idx]
        None => false
      }
    }
  }
}

///|
fn gto_compute_updates(
  flat : GTOFlatTypes,
  combined_infos : Array[Array[GTOFieldInfo]],
  public_types : Set[Int],
) -> (Map[Int, Array[Bool]], Map[Int, Array[Int]]) {
  let can_become_immutable : Map[Int, Array[Bool]] = Map::new()
  let indexes_after_removals : Map[Int, Array[Int]] = Map::new()
  let infos_subs_supers = gto_copy_field_infos(combined_infos)
  gto_propagate_to_super_and_subs(infos_subs_supers, flat)
  let infos_supers = gto_copy_field_infos(combined_infos)
  gto_propagate_to_subs(infos_supers, flat)
  let order = gto_supertypes_first_order(flat)
  for type_idx in order {
    if public_types.contains(type_idx) {
      continue
    }
    let fields = match flat.struct_fields[type_idx] {
      Some(fields) => fields
      None => continue
    }
    if flat.supers[type_idx].length() > 1 {
      continue
    }
    let infos_a = infos_subs_supers[type_idx]
    let infos_b = infos_supers[type_idx]
    for i in 0..<fields.length() {
      if !fields[i].is_mutable() {
        continue
      }
      if infos_a[i].has_write {
        continue
      }
      let mut super_ok = true
      for super_idx in flat.supers[type_idx] {
        if !gto_super_field_can_be_immutable(
            flat, can_become_immutable, super_idx, i,
          ) {
          super_ok = false
          break
        }
      }
      if super_ok {
        gto_mark_can_become_immutable(can_become_immutable, type_idx, i)
      }
    }
    let removable : Array[Bool] = []
    let mut has_removable = false
    for i in 0..<fields.length() {
      let no_reads_anywhere = !infos_a[i].has_read
      let no_reads_writes_in_supers = !infos_b[i].has_read &&
        !infos_b[i].has_write
      let rem = no_reads_anywhere || no_reads_writes_in_supers
      removable.push(rem)
      if rem {
        has_removable = true
      }
    }
    let super_opt = if flat.supers[type_idx].is_empty() {
      None
    } else {
      Some(flat.supers[type_idx][0])
    }
    let super_has_updates = match super_opt {
      Some(super_idx) => indexes_after_removals.contains(super_idx)
      None => false
    }
    if !has_removable && !super_has_updates {
      continue
    }
    let indexes = Array::make(fields.length(), 0)
    let mut next = 0
    let mut num_super_fields = 0
    match super_opt {
      Some(super_idx) => {
        let super_len = match flat.struct_fields[super_idx] {
          Some(super_fields) => super_fields.length()
          None => 0
        }
        let super_indexes = match indexes_after_removals.get(super_idx) {
          Some(existing) => existing.copy()
          None => gto_identity_indexes(super_len)
        }
        num_super_fields = super_indexes.length()
        let kept_not_in_super : Array[Int] = []
        for i in 0..<super_indexes.length() {
          let super_new_idx = super_indexes[i]
          if super_new_idx == gto_removed_field {
            if i < removable.length() && removable[i] {
              indexes[i] = gto_removed_field
            } else {
              kept_not_in_super.push(i)
            }
          } else {
            indexes[i] = super_new_idx
            if super_new_idx + 1 > next {
              next = super_new_idx + 1
            }
          }
        }
        for i in kept_not_in_super {
          indexes[i] = next
          next += 1
        }
      }
      None => ()
    }
    for i in num_super_fields..<fields.length() {
      if i < removable.length() && removable[i] {
        indexes[i] = gto_removed_field
      } else {
        indexes[i] = next
        next += 1
      }
    }
    if indexes != gto_identity_indexes(indexes.length()) {
      indexes_after_removals[type_idx] = indexes
    }
  }
  (can_become_immutable, indexes_after_removals)
}

///|
fn gto_apply_type_updates(
  mod : Module,
  flat : GTOFlatTypes,
  can_become_immutable : Map[Int, Array[Bool]],
  indexes_after_removals : Map[Int, Array[Int]],
) -> Module {
  let type_sec = match mod.type_sec {
    Some(type_sec) => type_sec
    None => return mod
  }
  let new_subtypes = flat.subtypes.copy()
  for i in 0..<new_subtypes.length() {
    let old_subtype = new_subtypes[i]
    let old_comp = old_subtype.get_comptype()
    let new_comp = match old_comp {
      StructCompType(fields) => {
        let updated_fields = fields.copy()
        match can_become_immutable.get(i) {
          Some(vec) =>
            for field_idx in 0..<vec.length() {
              if field_idx >= updated_fields.length() {
                break
              }
              if vec[field_idx] {
                let FieldType(st, _) = updated_fields[field_idx]
                updated_fields[field_idx] = FieldType::new(st, Const)
              }
            }
          None => ()
        }
        match indexes_after_removals.get(i) {
          Some(indexes) => {
            let kept_len = updated_fields.length() - gto_count_removed(indexes)
            let slots : Map[Int, FieldType] = Map::new()
            for field_idx in 0..<updated_fields.length() {
              let new_idx = indexes[field_idx]
              if new_idx != gto_removed_field {
                slots[new_idx] = updated_fields[field_idx]
              }
            }
            let out : Array[FieldType] = []
            for new_idx in 0..<kept_len {
              match slots.get(new_idx) {
                Some(field) => out.push(field)
                None => ()
              }
            }
            CompType::struct_(out)
          }
          None => CompType::struct_(updated_fields)
        }
      }
      _ => old_comp
    }
    let next_subtype = match old_subtype {
      SubType(is_final, supers, _) => SubType::new(is_final, supers, new_comp)
      CompTypeSubType(_) => SubType::comp_type(new_comp)
    }
    new_subtypes[i] = next_subtype
  }
  mod.with_type_sec(gto_rebuild_type_sec(type_sec, new_subtypes))
}

///|
fn gto_get_new_field_index(
  indexes_after_removals : Map[Int, Array[Int]],
  type_idx : TypeIdx,
  old_field_idx : Int,
) -> Int {
  let ti = gto_typeidx_raw_int(type_idx)
  match indexes_after_removals.get(ti) {
    None => old_field_idx
    Some(indexes) =>
      if old_field_idx < 0 || old_field_idx >= indexes.length() {
        old_field_idx
      } else {
        indexes[old_field_idx]
      }
  }
}

///|
fn gto_is_reorder_safe_operand(instr : TInstr) -> Bool {
  match instr {
    TI32Const(_) | TI64Const(_) | TF32Const(_) | TF64Const(_) => true
    TRefNull(_)
    | TRefFunc(_)
    | TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) => true
    TLocalGet(_) | TGlobalGet(_) => true
    _ => false
  }
}

///|
fn gto_may_trap(instr : TInstr) -> Bool {
  match instr {
    TI32Const(_) | TI64Const(_) | TF32Const(_) | TF64Const(_) => false
    TRefNull(_)
    | TRefFunc(_)
    | TV128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) => false
    TLocalGet(_) | TGlobalGet(_) | TNop => false
    _ => true
  }
}

///|
fn gto_count_imported_funcs(mod : Module) -> Int {
  let mut n = 0
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
fn gto_alloc_temp_local(
  next_local : Array[Int],
  extra_locals : Array[ValType],
  ty : ValType,
) -> LocalIdx {
  let idx = next_local[0]
  next_local[0] = idx + 1
  extra_locals.push(ty)
  LocalIdx::new(idx.reinterpret_as_uint())
}

///|
fn gto_build_reordered_operands(
  operands : Array[TInstr],
  indexes_after_removal : Array[Int],
) -> Result[Array[TInstr], String] {
  let kept = indexes_after_removal.length() -
    gto_count_removed(indexes_after_removal)
  let slots : Map[Int, TInstr] = Map::new()
  let upto = if operands.length() < indexes_after_removal.length() {
    operands.length()
  } else {
    indexes_after_removal.length()
  }
  for i in 0..<upto {
    let new_idx = indexes_after_removal[i]
    if new_idx != gto_removed_field {
      slots[new_idx] = operands[i]
    }
  }
  let out : Array[TInstr] = []
  for i in 0..<kept {
    match slots.get(i) {
      Some(instr) => out.push(instr)
      None => return Err("global_type_optimization: invalid field remap")
    }
  }
  Ok(out)
}

///|
fn gto_rewrite_function_texpr(
  body : TExpr,
  flat : GTOFlatTypes,
  indexes_after_removals : Map[Int, Array[Int]],
  next_local : Array[Int],
  extra_locals : Array[ValType],
) -> Result[TExpr, String] {
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    let rewritten = match self.walk_tinstruction_default((), instr) {
      Err(e) => return Err(e)
      Ok(None) => instr
      Ok(Some((_, next))) => next
    }
    match rewritten {
      TStructNew(type_idx, operands) => {
        let type_i = gto_typeidx_raw_int(type_idx)
        match indexes_after_removals.get(type_i) {
          None => change((), rewritten)
          Some(indexes) => {
            let remapped = match
              gto_build_reordered_operands(operands, indexes) {
              Ok(v) => v
              Err(e) => return Err(e)
            }
            let mut safe = true
            for operand in operands {
              if !gto_is_reorder_safe_operand(operand) {
                safe = false
                break
              }
            }
            if safe {
              change((), TInstr::struct_new(type_idx, remapped))
            } else {
              let fields = match flat.struct_fields.get(type_i) {
                Some(Some(fields)) => fields
                _ => return Err("global_type_optimization: missing struct type")
              }
              if operands.length() != fields.length() {
                return Err(
                  "global_type_optimization: struct.new field mismatch",
                )
              }
              let temp_by_old : Array[LocalIdx] = []
              let block_instrs : Array[TInstr] = []
              for i in 0..<operands.length() {
                let temp = gto_alloc_temp_local(
                  next_local,
                  extra_locals,
                  fields[i].unpack(),
                )
                temp_by_old.push(temp)
                block_instrs.push(TInstr::local_set(temp, operands[i]))
              }
              let new_ops : Array[TInstr] = []
              for old_i in 0..<indexes.length() {
                let new_i = indexes[old_i]
                if new_i == gto_removed_field {
                  continue
                }
                while new_ops.length() <= new_i {
                  new_ops.push(TInstr::nop())
                }
                new_ops[new_i] = TInstr::local_get(temp_by_old[old_i])
              }
              block_instrs.push(TInstr::struct_new(type_idx, new_ops))
              let bt = BlockType::val_type(
                ValType::ref_type(RefType::new(false, HeapType::new(type_idx))),
              )
              change((), TInstr::block(bt, TExpr::new(block_instrs)))
            }
          }
        }
      }
      TStructSet(type_idx, field_idx, ref_, value) => {
        let old_idx = gto_u32_to_int(field_idx)
        let new_idx = gto_get_new_field_index(
          indexes_after_removals, type_idx, old_idx,
        )
        if new_idx != gto_removed_field {
          change(
            (),
            TInstr::struct_set(
              type_idx,
              @lib.U32(new_idx.reinterpret_as_uint()),
              ref_,
              value,
            ),
          )
        } else {
          let temp_ref = gto_alloc_temp_local(
            next_local,
            extra_locals,
            ValType::ref_type(RefType::new(true, HeapType::new(type_idx))),
          )
          let replacement = TInstr::block(
            BlockType::void_(),
            TExpr::new([
              TInstr::local_set(temp_ref, ref_),
              TInstr::drop(value),
              TInstr::drop(TInstr::ref_as_non_null(TInstr::local_get(temp_ref))),
            ]),
          )
          change((), replacement)
        }
      }
      TStructGet(type_idx, field_idx, ref_) => {
        let old_idx = gto_u32_to_int(field_idx)
        let new_idx = gto_get_new_field_index(
          indexes_after_removals, type_idx, old_idx,
        )
        if new_idx == gto_removed_field {
          Err("global_type_optimization: removed field still read")
        } else {
          change(
            (),
            TInstr::struct_get(
              type_idx,
              @lib.U32(new_idx.reinterpret_as_uint()),
              ref_,
            ),
          )
        }
      }
      TStructGetS(type_idx, field_idx, ref_) => {
        let old_idx = gto_u32_to_int(field_idx)
        let new_idx = gto_get_new_field_index(
          indexes_after_removals, type_idx, old_idx,
        )
        if new_idx == gto_removed_field {
          Err("global_type_optimization: removed field still read")
        } else {
          change(
            (),
            TInstr::struct_get_s(
              type_idx,
              @lib.U32(new_idx.reinterpret_as_uint()),
              ref_,
            ),
          )
        }
      }
      TStructGetU(type_idx, field_idx, ref_) => {
        let old_idx = gto_u32_to_int(field_idx)
        let new_idx = gto_get_new_field_index(
          indexes_after_removals, type_idx, old_idx,
        )
        if new_idx == gto_removed_field {
          Err("global_type_optimization: removed field still read")
        } else {
          change(
            (),
            TInstr::struct_get_u(
              type_idx,
              @lib.U32(new_idx.reinterpret_as_uint()),
              ref_,
            ),
          )
        }
      }
      _ => change((), rewritten)
    }
  })
  match walker.walk_texpr((), body) {
    Err(e) => Err(e)
    Ok(None) => Ok(body)
    Ok(Some((_, next_body))) => Ok(next_body)
  }
}

///|
fn gto_rewrite_module_texpr(
  body : TExpr,
  flat : GTOFlatTypes,
  indexes_after_removals : Map[Int, Array[Int]],
  removed_trapping_inits : Array[(ValType, TInstr)],
) -> Result[TExpr, String] {
  let walker = ModuleTransformer::new().on_tinstruction_evt(fn(self, _, instr) {
    let rewritten = match self.walk_tinstruction_default((), instr) {
      Err(e) => return Err(e)
      Ok(None) => instr
      Ok(Some((_, next))) => next
    }
    match rewritten {
      TStructNew(type_idx, operands) => {
        let type_i = gto_typeidx_raw_int(type_idx)
        match indexes_after_removals.get(type_i) {
          None => change((), rewritten)
          Some(indexes) => {
            let remapped = match
              gto_build_reordered_operands(operands, indexes) {
              Ok(v) => v
              Err(e) => return Err(e)
            }
            match flat.struct_fields.get(type_i) {
              Some(Some(fields)) => {
                let upto = if indexes.length() < operands.length() {
                  indexes.length()
                } else {
                  operands.length()
                }
                for i in 0..<upto {
                  if indexes[i] == gto_removed_field &&
                    i < fields.length() &&
                    gto_may_trap(operands[i]) {
                    removed_trapping_inits.push(
                      (fields[i].unpack(), operands[i]),
                    )
                  }
                }
              }
              _ => ()
            }
            change((), TInstr::struct_new(type_idx, remapped))
          }
        }
      }
      TStructSet(type_idx, field_idx, ref_, value) => {
        let old_idx = gto_u32_to_int(field_idx)
        let new_idx = gto_get_new_field_index(
          indexes_after_removals, type_idx, old_idx,
        )
        if new_idx != gto_removed_field {
          change(
            (),
            TInstr::struct_set(
              type_idx,
              @lib.U32(new_idx.reinterpret_as_uint()),
              ref_,
              value,
            ),
          )
        } else {
          change(
            (),
            TInstr::block(
              BlockType::void_(),
              TExpr::new([
                TInstr::drop(value),
                TInstr::drop(TInstr::ref_as_non_null(ref_)),
              ]),
            ),
          )
        }
      }
      TStructGet(type_idx, field_idx, ref_) => {
        let old_idx = gto_u32_to_int(field_idx)
        let new_idx = gto_get_new_field_index(
          indexes_after_removals, type_idx, old_idx,
        )
        if new_idx == gto_removed_field {
          Err("global_type_optimization: removed field still read")
        } else {
          change(
            (),
            TInstr::struct_get(
              type_idx,
              @lib.U32(new_idx.reinterpret_as_uint()),
              ref_,
            ),
          )
        }
      }
      TStructGetS(type_idx, field_idx, ref_) => {
        let old_idx = gto_u32_to_int(field_idx)
        let new_idx = gto_get_new_field_index(
          indexes_after_removals, type_idx, old_idx,
        )
        if new_idx == gto_removed_field {
          Err("global_type_optimization: removed field still read")
        } else {
          change(
            (),
            TInstr::struct_get_s(
              type_idx,
              @lib.U32(new_idx.reinterpret_as_uint()),
              ref_,
            ),
          )
        }
      }
      TStructGetU(type_idx, field_idx, ref_) => {
        let old_idx = gto_u32_to_int(field_idx)
        let new_idx = gto_get_new_field_index(
          indexes_after_removals, type_idx, old_idx,
        )
        if new_idx == gto_removed_field {
          Err("global_type_optimization: removed field still read")
        } else {
          change(
            (),
            TInstr::struct_get_u(
              type_idx,
              @lib.U32(new_idx.reinterpret_as_uint()),
              ref_,
            ),
          )
        }
      }
      _ => change((), rewritten)
    }
  })
  match walker.walk_texpr((), body) {
    Err(e) => Err(e)
    Ok(None) => Ok(body)
    Ok(Some((_, next_body))) => Ok(next_body)
  }
}

///|
fn gto_rewrite_module_expr(
  expr : Expr,
  env : Env,
  flat : GTOFlatTypes,
  indexes_after_removals : Map[Int, Array[Int]],
  removed_trapping_inits : Array[(ValType, TInstr)],
) -> Result[Expr, String] {
  match to_texpr(expr, env) {
    Ok(texpr) =>
      match
        gto_rewrite_module_texpr(
          texpr, flat, indexes_after_removals, removed_trapping_inits,
        ) {
        Ok(next_texpr) => Ok(next_texpr.to_expr())
        Err(e) => Err(e)
      }
    Err(_) => Ok(expr)
  }
}

///|
fn gto_update_instructions(
  mod : Module,
  env : Env,
  flat : GTOFlatTypes,
  indexes_after_removals : Map[Int, Array[Int]],
) -> Result[Module, String] {
  let mut mod = mod
  let imported_funcs = gto_count_imported_funcs(mod)
  match mod.code_sec {
    Some(CodeSec(funcs)) => {
      let new_funcs : Array[Func] = []
      for def_idx in 0..<funcs.length() {
        let abs_idx = imported_funcs + def_idx
        let abs_func_idx = FuncIdx::new(abs_idx.reinterpret_as_uint())
        let param_count = match env.get_functype_by_funcidx(abs_func_idx) {
          Some(FuncType(params, _)) => params.length()
          None => 0
        }
        match funcs[def_idx] {
          TFunc(locals, body) => {
            let next_local = [param_count + locals.length()]
            let extra_locals : Array[ValType] = []
            let new_body = match
              gto_rewrite_function_texpr(
                body, flat, indexes_after_removals, next_local, extra_locals,
              ) {
              Ok(next_body) => next_body
              Err(e) => return Err(e)
            }
            let new_locals = locals.copy()
            for local_ty in extra_locals {
              new_locals.push(local_ty)
            }
            new_funcs.push(Func::t_func(new_locals, new_body))
          }
          Func(locals, body) =>
            match gto_expand_locals(locals) {
              Some(expanded) => {
                let local_env = env.with_locals(expanded)
                match to_texpr(body, local_env) {
                  Ok(texpr) => {
                    let next_local = [param_count + expanded.length()]
                    let extra_locals : Array[ValType] = []
                    let next_texpr = match
                      gto_rewrite_function_texpr(
                        texpr, flat, indexes_after_removals, next_local, extra_locals,
                      ) {
                      Ok(next_texpr) => next_texpr
                      Err(e) => return Err(e)
                    }
                    let all_locals = expanded.copy()
                    for local_ty in extra_locals {
                      all_locals.push(local_ty)
                    }
                    new_funcs.push(
                      Func::new(
                        tlocals_to_locals(all_locals),
                        next_texpr.to_expr(),
                      ),
                    )
                  }
                  Err(_) => new_funcs.push(funcs[def_idx])
                }
              }
              None => new_funcs.push(funcs[def_idx])
            }
        }
      }
      mod = mod.with_code_sec(CodeSec::new(new_funcs))
    }
    None => ()
  }
  let removed_trapping_inits : Array[(ValType, TInstr)] = []
  match mod.global_sec {
    Some(GlobalSec(globals)) => {
      let next_globals : Array[Global] = []
      for global in globals {
        let Global(global_type, init) = global
        let next_init = match
          gto_rewrite_module_expr(
            init, env, flat, indexes_after_removals, removed_trapping_inits,
          ) {
          Ok(expr) => expr
          Err(e) => return Err(e)
        }
        next_globals.push(Global::new(global_type, next_init))
      }
      mod = mod.with_global_sec(GlobalSec::new(next_globals))
    }
    None => ()
  }
  match mod.table_sec {
    Some(TableSec(tables)) => {
      let next_tables : Array[Table] = []
      for table in tables {
        let Table(table_type, init_expr) = table
        let next_init = match init_expr {
          Some(expr) =>
            match
              gto_rewrite_module_expr(
                expr, env, flat, indexes_after_removals, removed_trapping_inits,
              ) {
              Ok(next_expr) => Some(next_expr)
              Err(e) => return Err(e)
            }
          None => None
        }
        next_tables.push(Table::new(table_type, next_init))
      }
      mod = mod.with_table_sec(TableSec::new(next_tables))
    }
    None => ()
  }
  match mod.elem_sec {
    Some(ElemSec(elems)) => {
      let next_elems : Array[Elem] = []
      for elem in elems {
        let Elem(mode, kind) = elem
        let next_mode = match mode {
          Active(table_idx, offset) =>
            match
              gto_rewrite_module_expr(
                offset, env, flat, indexes_after_removals, removed_trapping_inits,
              ) {
              Ok(next_offset) => ElemMode::active(table_idx, next_offset)
              Err(e) => return Err(e)
            }
          Passive => ElemMode::passive()
          Declarative => ElemMode::declarative()
        }
        let next_kind = match kind {
          FuncsElemKind(funcs) => ElemKind::funcs(funcs)
          FuncExprsElemKind(exprs) => {
            let next_exprs : Array[Expr] = []
            for expr in exprs {
              match
                gto_rewrite_module_expr(
                  expr, env, flat, indexes_after_removals, removed_trapping_inits,
                ) {
                Ok(next_expr) => next_exprs.push(next_expr)
                Err(e) => return Err(e)
              }
            }
            ElemKind::func_exprs(next_exprs)
          }
          TypedExprsElemKind(rt, exprs) => {
            let next_exprs : Array[Expr] = []
            for expr in exprs {
              match
                gto_rewrite_module_expr(
                  expr, env, flat, indexes_after_removals, removed_trapping_inits,
                ) {
                Ok(next_expr) => next_exprs.push(next_expr)
                Err(e) => return Err(e)
              }
            }
            ElemKind::typed_exprs(rt, next_exprs)
          }
        }
        next_elems.push(Elem::new(next_mode, next_kind))
      }
      mod = mod.with_elem_sec(ElemSec::new(next_elems))
    }
    None => ()
  }
  match mod.data_sec {
    Some(DataSec(datas)) => {
      let next_datas : Array[Data] = []
      for data in datas {
        let Data(mode, bytes) = data
        let next_mode = match mode {
          Active(mem_idx, offset) =>
            match
              gto_rewrite_module_expr(
                offset, env, flat, indexes_after_removals, removed_trapping_inits,
              ) {
              Ok(next_offset) => DataMode::active(mem_idx, next_offset)
              Err(e) => return Err(e)
            }
          Passive => DataMode::passive()
        }
        next_datas.push(Data::new(next_mode, bytes))
      }
      mod = mod.with_data_sec(DataSec::new(next_datas))
    }
    None => ()
  }
  if !removed_trapping_inits.is_empty() {
    let next_globals = match mod.global_sec {
      Some(GlobalSec(globals)) => globals.copy()
      None => []
    }
    for item in removed_trapping_inits {
      let (vt, instr) = item
      next_globals.push(
        Global::new(GlobalType::new(vt, false), TExpr::new([instr]).to_expr()),
      )
    }
    mod = mod.with_global_sec(GlobalSec::new(next_globals))
  }
  Ok(mod)
}

///|
fn global_type_optimization(mod : Module) -> Result[Module, String] {
  let type_sec = match mod.type_sec {
    Some(type_sec) => type_sec
    None => return Ok(mod)
  }
  let flat = gto_flatten_types(type_sec)
  if flat.subtypes.is_empty() {
    return Ok(mod)
  }
  let combined_infos : Array[Array[GTOFieldInfo]] = []
  for i in 0..<flat.subtypes.length() {
    match flat.struct_fields[i] {
      Some(fields) =>
        combined_infos.push(gto_make_field_info_vec(fields.length()))
      None => combined_infos.push([])
    }
  }
  let env = Env::new().with_module(mod)
  gto_scan_module_uses(mod, env, combined_infos)
  let public_types = gto_collect_public_types(mod, flat)
  let (can_become_immutable, indexes_after_removals) = gto_compute_updates(
    flat, combined_infos, public_types,
  )
  if can_become_immutable.is_empty() && indexes_after_removals.is_empty() {
    return Ok(mod)
  }
  let mod = if indexes_after_removals.is_empty() {
    mod
  } else {
    match gto_update_instructions(mod, env, flat, indexes_after_removals) {
      Ok(next_mod) => next_mod
      Err(e) => return Err(e)
    }
  }
  Ok(
    gto_apply_type_updates(
      mod, flat, can_become_immutable, indexes_after_removals,
    ),
  )
}

// ============================================================
// Tests
// ============================================================

///|
fn gto_get_struct_fields(mod : Module, idx : Int) -> Array[FieldType]? {
  match mod.type_sec {
    Some(TypeSec(recs)) =>
      match recs.get(idx) {
        Some(SingleRecType(st)) =>
          match st.get_comptype() {
            StructCompType(fields) => Some(fields)
            _ => None
          }
        _ => None
      }
    None => None
  }
}

///|
test "global type optimization makes mutable field immutable when no struct.set exists" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let func_type = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type, func_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::struct_get(
                TypeIdx::new(0),
                @lib.U32(0),
                TInstr::struct_new(TypeIdx::new(0), [TInstr::i32_const(I32(42))]),
              ),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match global_type_optimization(mod) {
    Ok(next_mod) => next_mod
    Err(e) => fail("unexpected global_type_optimization error: \{e}")
  }
  match gto_get_struct_fields(optimized, 0) {
    Some([FieldType(_, mutability)]) => assert_eq(mutability, Const)
    _ => fail("expected one immutable field")
  }
}

///|
test "global type optimization removes unread field and remaps struct indexes" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let func_type = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type, func_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::struct_get(
                TypeIdx::new(0),
                @lib.U32(1),
                TInstr::struct_new(TypeIdx::new(0), [
                  TInstr::i32_const(I32(11)),
                  TInstr::i32_const(I32(22)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match global_type_optimization(mod) {
    Ok(next_mod) => next_mod
    Err(e) => fail("unexpected global_type_optimization error: \{e}")
  }
  match gto_get_struct_fields(optimized, 0) {
    Some(fields) => assert_eq(fields.length(), 1)
    None => fail("expected struct fields")
  }
  match optimized.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            TExpr([TDrop(TStructGet(_, @lib.U32(idx), TStructNew(_, ops)))])
          ),
        ]
      )
    ) => {
      assert_eq(idx, 0U)
      assert_eq(ops.length(), 1)
      match ops[0] {
        TI32Const(I32(v)) => assert_eq(v, 22)
        _ => fail("expected remaining operand to be i32.const 22")
      }
    }
    _ => fail("expected rewritten struct.get/struct.new")
  }
}

///|
test "global type optimization keeps public struct types unchanged" {
  let struct_type = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
  let func_type = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let global_ref = ValType::ref_type(
    RefType::new(true, HeapType::new(TypeIdx::new(0))),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type, func_type]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(global_ref, false),
          Expr::new([
            Instruction::i32_const(I32(1)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
      ]),
    )
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("g"), ExternIdx::global(GlobalIdx::new(0))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1)]))
    .with_code_sec(
      CodeSec::new([Func::t_func([], TExpr::new([TInstr::nop()]))]),
    )
  let optimized = match global_type_optimization(mod) {
    Ok(next_mod) => next_mod
    Err(e) => fail("unexpected global_type_optimization error: \{e}")
  }
  match gto_get_struct_fields(optimized, 0) {
    Some([FieldType(_, mutability)]) => assert_eq(mutability, Var)
    _ => fail("expected public field to stay mutable")
  }
}

///|
test "global type optimization updates subtype layout to follow supertype removals" {
  let field = FieldType::new(StorageType::val_type(ValType::i32()), Var)
  let super_type = single_rec_type(
    comp_type_sub_type(struct_comp_type([field, field])),
  )
  let sub_type = single_rec_type(
    SubType::new(
      false,
      [TypeIdx::new(0)],
      struct_comp_type([field, field, field]),
    ),
  )
  let func_type = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([super_type, sub_type, func_type]))
    .with_func_sec(FuncSec::new([TypeIdx::new(2)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::struct_get(
                TypeIdx::new(0),
                @lib.U32(1),
                TInstr::struct_new(TypeIdx::new(0), [
                  TInstr::i32_const(I32(1)),
                  TInstr::i32_const(I32(2)),
                ]),
              ),
            ),
            TInstr::drop(
              TInstr::struct_get(
                TypeIdx::new(1),
                @lib.U32(2),
                TInstr::struct_new(TypeIdx::new(1), [
                  TInstr::i32_const(I32(10)),
                  TInstr::i32_const(I32(20)),
                  TInstr::i32_const(I32(30)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match global_type_optimization(mod) {
    Ok(next_mod) => next_mod
    Err(e) => fail("unexpected global_type_optimization error: \{e}")
  }
  match gto_get_struct_fields(optimized, 0) {
    Some(fields) => assert_eq(fields.length(), 1)
    None => fail("expected optimized supertype")
  }
  match gto_get_struct_fields(optimized, 1) {
    Some(fields) => assert_eq(fields.length(), 2)
    None => fail("expected optimized subtype")
  }
}

///|
test "global type optimization preserves removed trapping module-init operands" {
  let field_ref = FieldType::new(
    StorageType::val_type(
      ValType::ref_type(RefType::new(false, HeapType::abs(AbsHeapType::func()))),
    ),
    Var,
  )
  let field_i32 = FieldType::new(StorageType::val_type(ValType::i32()), Var)
  let struct_type = single_rec_type(
    comp_type_sub_type(struct_comp_type([field_ref, field_i32])),
  )
  let mod = Module::new()
    .with_type_sec(TypeSec::new([struct_type]))
    .with_global_sec(
      GlobalSec::new([
        Global::new(
          GlobalType::new(
            ValType::ref_type(
              RefType::new(true, HeapType::new(TypeIdx::new(0))),
            ),
            false,
          ),
          Expr::new([
            Instruction::ref_null(HeapType::abs(AbsHeapType::func())),
            Instruction::ref_as_non_null(),
            Instruction::i32_const(I32(7)),
            Instruction::struct_new(TypeIdx::new(0)),
          ]),
        ),
      ]),
    )
  let optimized = match global_type_optimization(mod) {
    Ok(next_mod) => next_mod
    Err(e) => fail("unexpected global_type_optimization error: \{e}")
  }
  match optimized.global_sec {
    Some(GlobalSec(globals)) => assert_true(globals.length() >= 2)
    None => fail("expected globals")
  }
}
