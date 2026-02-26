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
priv struct RTFlatTypes {
  subtypes : Array[SubType]
  group_starts : Array[Int]
  groups : Array[Array[Int]]
  type_to_group : Array[Int]
}

///|
let rt_min_factor = 0.0

///|
let rt_max_factor = 1.0

///|
let rt_num_factors = 21

///|
fn rt_single_void_type() -> RecType {
  single_rec_type(comp_type_sub_type(func_comp_type([], [])))
}

///|
fn rt_flatten_types(type_sec : TypeSec) -> RTFlatTypes {
  let TypeSec(recs) = type_sec
  let subtypes : Array[SubType] = []
  let group_starts : Array[Int] = []
  let groups : Array[Array[Int]] = []
  let type_to_group : Array[Int] = []
  let mut next = 0
  let mut g = 0
  for rec in recs {
    match rec {
      SingleRecType(st) => {
        subtypes.push(st)
        group_starts.push(next)
        groups.push([next])
        type_to_group.push(g)
        next += 1
      }
      GroupRecType(sts) => {
        let start = next
        let group : Array[Int] = []
        for st in sts {
          subtypes.push(st)
          group_starts.push(start)
          group.push(next)
          type_to_group.push(g)
          next += 1
        }
        groups.push(group)
      }
    }
    g += 1
  }
  { subtypes, group_starts, groups, type_to_group }
}

///|
fn rt_resolve_type_idx(
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
fn rt_collect_valtype_refs(
  out : Array[Int],
  vt : ValType,
  group_start : Int,
  total : Int,
) -> Unit {
  match vt {
    RefTypeValType(rt) =>
      match rt {
        HeapTypeRefType(_, ht) =>
          match ht {
            HeapType(type_idx) =>
              match rt_resolve_type_idx(type_idx, group_start, total) {
                Some(idx) => out.push(idx)
                None => ()
              }
            _ => ()
          }
        _ => ()
      }
    _ => ()
  }
}

///|
fn rt_collect_storage_refs(
  out : Array[Int],
  st : StorageType,
  group_start : Int,
  total : Int,
) -> Unit {
  match st {
    ValTypeStorageType(vt) =>
      rt_collect_valtype_refs(out, vt, group_start, total)
    _ => ()
  }
}

///|
fn rt_collect_subtype_refs(
  subtype : SubType,
  group_start : Int,
  total : Int,
) -> Array[Int] {
  let out : Array[Int] = []
  for super_idx in subtype.super_types() {
    match rt_resolve_type_idx(super_idx, group_start, total) {
      Some(idx) => out.push(idx)
      None => ()
    }
  }
  match subtype.get_comptype() {
    FuncCompType(params, results) => {
      for p in params {
        rt_collect_valtype_refs(out, p, group_start, total)
      }
      for r in results {
        rt_collect_valtype_refs(out, r, group_start, total)
      }
    }
    StructCompType(fields) =>
      for field in fields {
        let FieldType(st, _) = field
        rt_collect_storage_refs(out, st, group_start, total)
      }
    ArrayCompType(field) => {
      let FieldType(st, _) = field
      rt_collect_storage_refs(out, st, group_start, total)
    }
  }
  out
}

///|
fn rt_unique_sorted(values : Array[Int]) -> Array[Int] {
  let out = values.copy()
  out.sort()
  let dedup : Array[Int] = []
  for v in out {
    if dedup.is_empty() || dedup[dedup.length() - 1] != v {
      dedup.push(v)
    }
  }
  dedup
}

///|
fn rt_collect_func_type_idx_by_func(mod : Module) -> Map[FuncIdx, TypeIdx] {
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
fn rt_collect_all_global_types(mod : Module) -> Array[GlobalType] {
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
fn rt_collect_all_table_types(mod : Module) -> Array[TableType] {
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
fn rt_collect_all_tag_types(mod : Module) -> Array[TagType] {
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
fn rt_mark_public_type(
  public_types : Set[Int],
  flat : RTFlatTypes,
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
      ref_ in rt_collect_subtype_refs(
        flat.subtypes[curr],
        flat.group_starts[curr],
        flat.subtypes.length(),
      ) {
      stack.push(ref_)
    }
  }
}

///|
fn rt_mark_public_valtype(
  public_types : Set[Int],
  flat : RTFlatTypes,
  vt : ValType,
) -> Unit {
  match vt {
    RefTypeValType(HeapTypeRefType(_, HeapType(type_idx))) =>
      match rt_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
        Some(idx) => rt_mark_public_type(public_types, flat, idx)
        None => ()
      }
    _ => ()
  }
}

///|
fn rt_mark_public_reftype(
  public_types : Set[Int],
  flat : RTFlatTypes,
  rt : RefType,
) -> Unit {
  match rt {
    HeapTypeRefType(_, HeapType(type_idx)) =>
      match rt_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
        Some(idx) => rt_mark_public_type(public_types, flat, idx)
        None => ()
      }
    _ => ()
  }
}

///|
fn rt_collect_public_types(mod : Module, flat : RTFlatTypes) -> Set[Int] {
  let public_types : Set[Int] = Set::new()
  let func_types = rt_collect_func_type_idx_by_func(mod)
  let global_types = rt_collect_all_global_types(mod)
  let table_types = rt_collect_all_table_types(mod)
  let tag_types = rt_collect_all_tag_types(mod)
  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(type_idx)) =>
            match rt_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
              Some(idx) => rt_mark_public_type(public_types, flat, idx)
              None => ()
            }
          Import(_, _, TagExternType(TagType(type_idx))) =>
            match rt_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
              Some(idx) => rt_mark_public_type(public_types, flat, idx)
              None => ()
            }
          Import(_, _, GlobalExternType(GlobalType(vt, _))) =>
            rt_mark_public_valtype(public_types, flat, vt)
          Import(_, _, TableExternType(TableType(rt, _))) =>
            rt_mark_public_reftype(public_types, flat, rt)
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
                match rt_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
                  Some(idx) => rt_mark_public_type(public_types, flat, idx)
                  None => ()
                }
              None => ()
            }
          GlobalExternIdx(GlobalIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < global_types.length() {
              let GlobalType(vt, _) = global_types[idx]
              rt_mark_public_valtype(public_types, flat, vt)
            }
          }
          TableExternIdx(TableIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < table_types.length() {
              let TableType(rt, _) = table_types[idx]
              rt_mark_public_reftype(public_types, flat, rt)
            }
          }
          TagExternIdx(TagIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < tag_types.length() {
              let TagType(type_idx) = tag_types[idx]
              match rt_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
                Some(type_i) => rt_mark_public_type(public_types, flat, type_i)
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
    let g = flat.type_to_group[idx]
    for t in flat.groups[g] {
      public_types.add(t)
    }
  }
  public_types
}

///|
fn rt_has_gc_types(flat : RTFlatTypes) -> Bool {
  for subtype in flat.subtypes {
    match subtype.get_comptype() {
      StructCompType(_) | ArrayCompType(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn rt_collect_non_type_use_counts(mod : Module, counts : Array[Int]) -> Unit {
  let walker = ModuleTransformer::new().on_typeidx_evt(fn(_, _, tidx) {
    match tidx {
      TypeIdx(i) => {
        let raw = i.reinterpret_as_int()
        if raw >= 0 && raw < counts.length() {
          counts[raw] = counts[raw] + 1
        }
      }
      RecIdx(_) => ()
    }
    unchanged()
  })
  match mod.import_sec {
    Some(sec) => ignore(walker.walk_importsec((), sec))
    None => ()
  }
  match mod.func_sec {
    Some(sec) => ignore(walker.walk_funcsec((), sec))
    None => ()
  }
  match mod.table_sec {
    Some(sec) => ignore(walker.walk_tablesec((), sec))
    None => ()
  }
  match mod.mem_sec {
    Some(sec) => ignore(walker.walk_memsec((), sec))
    None => ()
  }
  match mod.tag_sec {
    Some(sec) => ignore(walker.walk_tagsec((), sec))
    None => ()
  }
  match mod.global_sec {
    Some(sec) => ignore(walker.walk_globalsec((), sec))
    None => ()
  }
  match mod.export_sec {
    Some(sec) => ignore(walker.walk_exportsec((), sec))
    None => ()
  }
  match mod.start_sec {
    Some(sec) => ignore(walker.walk_startsec((), sec))
    None => ()
  }
  match mod.elem_sec {
    Some(sec) => ignore(walker.walk_elemsec((), sec))
    None => ()
  }
  match mod.data_cnt_sec {
    Some(sec) => ignore(walker.walk_datacntsec((), sec))
    None => ()
  }
  match mod.code_sec {
    Some(sec) => ignore(walker.walk_codesec((), sec))
    None => ()
  }
  match mod.data_sec {
    Some(sec) => ignore(walker.walk_datasec((), sec))
    None => ()
  }
}

///|
fn rt_collect_type_def_use_counts(
  flat : RTFlatTypes,
  counts : Array[Int],
) -> Unit {
  for idx = 0; idx < flat.subtypes.length(); idx = idx + 1 {
    for
      ref_ in rt_collect_subtype_refs(
        flat.subtypes[idx],
        flat.group_starts[idx],
        flat.subtypes.length(),
      ) {
      counts[ref_] = counts[ref_] + 1
    }
  }
}

///|
fn rt_topological_sort(succs : Array[Array[Int]]) -> Array[Int] {
  let n = succs.length()
  let indegree = Array::make(n, 0)
  for src = 0; src < n; src = src + 1 {
    for dst in succs[src] {
      indegree[dst] = indegree[dst] + 1
    }
  }
  let queue : Array[Int] = []
  for i = 0; i < n; i = i + 1 {
    if indegree[i] == 0 {
      queue.push(i)
    }
  }
  let out : Array[Int] = []
  let mut qi = 0
  while qi < queue.length() {
    let curr = queue[qi]
    qi = qi + 1
    out.push(curr)
    for dep in succs[curr] {
      indegree[dep] = indegree[dep] - 1
      if indegree[dep] == 0 {
        queue.push(dep)
      }
    }
  }
  if out.length() < n {
    let seen = Array::make(n, false)
    for idx in out {
      seen[idx] = true
    }
    for i = 0; i < n; i = i + 1 {
      if !seen[i] {
        out.push(i)
      }
    }
  }
  out
}

///|
fn rt_min_topological_sort(
  succs : Array[Array[Int]],
  prefer_before : (Int, Int) -> Bool,
) -> Array[Int] {
  let n = succs.length()
  let indegree = Array::make(n, 0)
  for src = 0; src < n; src = src + 1 {
    for dst in succs[src] {
      indegree[dst] = indegree[dst] + 1
    }
  }
  let emitted = Array::make(n, false)
  let available : Array[Int] = []
  for i = 0; i < n; i = i + 1 {
    if indegree[i] == 0 {
      available.push(i)
    }
  }
  let out : Array[Int] = []
  while out.length() < n {
    if available.is_empty() {
      for i = 0; i < n; i = i + 1 {
        if !emitted[i] {
          available.push(i)
          break
        }
      }
    }
    let mut best_pos = 0
    let mut best = available[0]
    for pos = 1; pos < available.length(); pos = pos + 1 {
      let candidate = available[pos]
      if prefer_before(candidate, best) {
        best = candidate
        best_pos = pos
      }
    }
    let last = available.pop().unwrap()
    if best_pos < available.length() {
      available[best_pos] = last
    }
    if emitted[best] {
      continue
    }
    emitted[best] = true
    out.push(best)
    for dep in succs[best] {
      indegree[dep] = indegree[dep] - 1
      if indegree[dep] == 0 && !emitted[dep] {
        available.push(dep)
      }
    }
  }
  out
}

///|
fn rt_get_factor(i : Int) -> Double {
  rt_min_factor +
  (rt_max_factor - rt_min_factor) *
  i.to_double() /
  (rt_num_factors - 1).to_double()
}

///|
fn rt_get_cost(
  order : Array[Int],
  counts : Array[Int],
  for_testing : Bool,
) -> Int {
  let bits_per_byte = if for_testing { 1 } else { 7 }
  let indices_per_byte = 1 << bits_per_byte
  let mut cost = 0
  let mut num_bytes = 1
  let mut max_index = indices_per_byte
  for i = 0; i < order.length(); i = i + 1 {
    if i == max_index {
      num_bytes += 1
      max_index = max_index * indices_per_byte
    }
    cost += num_bytes * counts[order[i]]
  }
  cost
}

///|
fn rt_sort_group(
  group : Array[Int],
  flat : RTFlatTypes,
  all_counts : Array[Int],
  for_testing : Bool,
) -> Array[Int] {
  if group.length() <= 1 {
    return group.copy()
  }
  let local_of_abs : Map[Int, Int] = Map::new()
  for i = 0; i < group.length(); i = i + 1 {
    local_of_abs[group[i]] = i
  }
  let succs : Array[Array[Int]] = Array::make(group.length(), [])
  let local_counts : Array[Int] = []
  for abs_idx in group {
    local_counts.push(all_counts[abs_idx])
  }
  for src = 0; src < group.length(); src = src + 1 {
    let abs_idx = group[src]
    let refs = rt_collect_subtype_refs(
      flat.subtypes[abs_idx],
      flat.group_starts[abs_idx],
      flat.subtypes.length(),
    )
    let nexts : Array[Int] = []
    for ref_ in refs {
      match local_of_abs.get(ref_) {
        Some(dst) => nexts.push(dst)
        None => ()
      }
    }
    succs[src] = rt_unique_sorted(nexts)
  }
  let succs_first_forward = rt_topological_sort(succs)
  let succs_first : Array[Int] = []
  for i = 0; i < succs_first_forward.length(); i = i + 1 {
    succs_first.push(succs_first_forward[succs_first_forward.length() - 1 - i])
  }
  let mut best_sort : Array[Int] = []
  let mut best_cost = 0
  for factor_index = 0
      factor_index < rt_num_factors
      factor_index = factor_index + 1 {
    let factor = rt_get_factor(factor_index)
    let weights : Array[Double] = []
    for c in local_counts {
      weights.push(c.to_double())
    }
    for pred in succs_first {
      for succ in succs[pred] {
        weights[pred] = weights[pred] + weights[succ] * factor
      }
    }
    let sort = rt_min_topological_sort(succs, fn(a, b) {
      if weights[a] == weights[b] {
        a < b
      } else {
        weights[a] > weights[b]
      }
    })
    let cost = rt_get_cost(sort, local_counts, for_testing)
    if factor_index == 0 || cost < best_cost {
      best_sort = sort
      best_cost = cost
    }
  }
  let out : Array[Int] = []
  for i in best_sort {
    out.push(group[i])
  }
  out
}

///|
fn rt_rewrite_typeidx(
  type_idx : TypeIdx,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  old_to_new : Map[Int, TypeIdx],
) -> Result[TypeIdx, String] {
  match rt_resolve_type_idx(type_idx, group_start, total) {
    Some(abs_idx) =>
      match local_pos_by_old.get(abs_idx) {
        Some(pos) => Ok(TypeIdx::rec(pos.reinterpret_as_uint()))
        None =>
          match old_to_new.get(abs_idx) {
            Some(next_idx) => Ok(next_idx)
            None => Err("reorder_types: missing remap")
          }
      }
    None => Ok(type_idx)
  }
}

///|
fn rt_rewrite_heaptype(
  ht : HeapType,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  old_to_new : Map[Int, TypeIdx],
) -> Result[HeapType, String] {
  match ht {
    HeapType(type_idx) =>
      match
        rt_rewrite_typeidx(
          type_idx, group_start, total, local_pos_by_old, old_to_new,
        ) {
        Ok(next_idx) => Ok(HeapType::new(next_idx))
        Err(e) => Err(e)
      }
    _ => Ok(ht)
  }
}

///|
fn rt_rewrite_reftype(
  rt : RefType,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  old_to_new : Map[Int, TypeIdx],
) -> Result[RefType, String] {
  match rt {
    HeapTypeRefType(nullable, ht) =>
      match
        rt_rewrite_heaptype(
          ht, group_start, total, local_pos_by_old, old_to_new,
        ) {
        Ok(next_ht) => Ok(RefType::new(nullable, next_ht))
        Err(e) => Err(e)
      }
    _ => Ok(rt)
  }
}

///|
fn rt_rewrite_valtype(
  vt : ValType,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  old_to_new : Map[Int, TypeIdx],
) -> Result[ValType, String] {
  match vt {
    RefTypeValType(rt) =>
      match
        rt_rewrite_reftype(rt, group_start, total, local_pos_by_old, old_to_new) {
        Ok(next_rt) => Ok(ValType::ref_type(next_rt))
        Err(e) => Err(e)
      }
    _ => Ok(vt)
  }
}

///|
fn rt_rewrite_storage(
  st : StorageType,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  old_to_new : Map[Int, TypeIdx],
) -> Result[StorageType, String] {
  match st {
    ValTypeStorageType(vt) =>
      match
        rt_rewrite_valtype(vt, group_start, total, local_pos_by_old, old_to_new) {
        Ok(next_vt) => Ok(StorageType::val_type(next_vt))
        Err(e) => Err(e)
      }
    _ => Ok(st)
  }
}

///|
fn rt_rewrite_subtype(
  subtype : SubType,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  old_to_new : Map[Int, TypeIdx],
) -> Result[SubType, String] {
  match subtype {
    SubType(is_final, supers, ct) => {
      let next_supers : Array[TypeIdx] = []
      for super_idx in supers {
        match
          rt_rewrite_typeidx(
            super_idx, group_start, total, local_pos_by_old, old_to_new,
          ) {
          Ok(next_idx) => next_supers.push(next_idx)
          Err(e) => return Err(e)
        }
      }
      let next_ct = match ct {
        FuncCompType(params, results) => {
          let next_params : Array[ValType] = []
          let next_results : Array[ValType] = []
          for p in params {
            match
              rt_rewrite_valtype(
                p, group_start, total, local_pos_by_old, old_to_new,
              ) {
              Ok(v) => next_params.push(v)
              Err(e) => return Err(e)
            }
          }
          for r in results {
            match
              rt_rewrite_valtype(
                r, group_start, total, local_pos_by_old, old_to_new,
              ) {
              Ok(v) => next_results.push(v)
              Err(e) => return Err(e)
            }
          }
          CompType::func(next_params, next_results)
        }
        StructCompType(fields) => {
          let next_fields : Array[FieldType] = []
          for field in fields {
            let FieldType(storage, mut_) = field
            match
              rt_rewrite_storage(
                storage, group_start, total, local_pos_by_old, old_to_new,
              ) {
              Ok(next_storage) =>
                next_fields.push(FieldType::new(next_storage, mut_))
              Err(e) => return Err(e)
            }
          }
          CompType::struct_(next_fields)
        }
        ArrayCompType(field) => {
          let FieldType(storage, mut_) = field
          let next_storage = match
            rt_rewrite_storage(
              storage, group_start, total, local_pos_by_old, old_to_new,
            ) {
            Ok(v) => v
            Err(e) => return Err(e)
          }
          CompType::array(FieldType::new(next_storage, mut_))
        }
      }
      Ok(SubType::new(is_final, next_supers, next_ct))
    }
    CompTypeSubType(ct) => {
      let next_ct = match ct {
        FuncCompType(params, results) => {
          let next_params : Array[ValType] = []
          let next_results : Array[ValType] = []
          for p in params {
            match
              rt_rewrite_valtype(
                p, group_start, total, local_pos_by_old, old_to_new,
              ) {
              Ok(v) => next_params.push(v)
              Err(e) => return Err(e)
            }
          }
          for r in results {
            match
              rt_rewrite_valtype(
                r, group_start, total, local_pos_by_old, old_to_new,
              ) {
              Ok(v) => next_results.push(v)
              Err(e) => return Err(e)
            }
          }
          CompType::func(next_params, next_results)
        }
        StructCompType(fields) => {
          let next_fields : Array[FieldType] = []
          for field in fields {
            let FieldType(storage, mut_) = field
            match
              rt_rewrite_storage(
                storage, group_start, total, local_pos_by_old, old_to_new,
              ) {
              Ok(next_storage) =>
                next_fields.push(FieldType::new(next_storage, mut_))
              Err(e) => return Err(e)
            }
          }
          CompType::struct_(next_fields)
        }
        ArrayCompType(field) => {
          let FieldType(storage, mut_) = field
          let next_storage = match
            rt_rewrite_storage(
              storage, group_start, total, local_pos_by_old, old_to_new,
            ) {
            Ok(v) => v
            Err(e) => return Err(e)
          }
          CompType::array(FieldType::new(next_storage, mut_))
        }
      }
      Ok(SubType::comp_type(next_ct))
    }
  }
}

///|
fn reorder_types(
  mod : Module,
  for_testing? : Bool = false,
) -> Result[Module, String] {
  let type_sec = match mod.type_sec {
    Some(type_sec) => type_sec
    None => return Ok(mod)
  }
  let flat = rt_flatten_types(type_sec)
  if flat.subtypes.is_empty() || !rt_has_gc_types(flat) {
    return Ok(mod)
  }
  let public_types = rt_collect_public_types(mod, flat)
  let counts = Array::make(flat.subtypes.length(), 0)
  rt_collect_non_type_use_counts(mod, counts)
  rt_collect_type_def_use_counts(flat, counts)
  let group_orders : Array[Array[Int]] = []
  let mut changed = false
  for group in flat.groups {
    let mut is_private = true
    for idx in group {
      if public_types.contains(idx) {
        is_private = false
        break
      }
    }
    if is_private && group.length() > 1 {
      let sorted = rt_sort_group(group, flat, counts, for_testing)
      if sorted != group {
        changed = true
      }
      group_orders.push(sorted)
    } else {
      group_orders.push(group.copy())
    }
  }
  if !changed {
    return Ok(mod)
  }
  let old_to_new : Map[Int, TypeIdx] = Map::new()
  for gi = 0; gi < flat.groups.length(); gi = gi + 1 {
    let group = flat.groups[gi]
    let order = group_orders[gi]
    let start = group[0]
    for pos = 0; pos < order.length(); pos = pos + 1 {
      old_to_new[order[pos]] = TypeIdx::new((start + pos).reinterpret_as_uint())
    }
  }
  let new_recs : Array[RecType] = []
  for gi = 0; gi < flat.groups.length(); gi = gi + 1 {
    let order = group_orders[gi]
    let local_pos_by_old : Map[Int, Int] = Map::new()
    for i = 0; i < order.length(); i = i + 1 {
      local_pos_by_old[order[i]] = i
    }
    let next_subtypes : Array[SubType] = []
    for old_idx in order {
      match
        rt_rewrite_subtype(
          flat.subtypes[old_idx],
          flat.group_starts[old_idx],
          flat.subtypes.length(),
          local_pos_by_old,
          old_to_new,
        ) {
        Ok(next_subtype) => next_subtypes.push(next_subtype)
        Err(e) => return Err(e)
      }
    }
    if next_subtypes.length() == 1 {
      new_recs.push(RecType::new(next_subtypes[0]))
    } else {
      new_recs.push(RecType::group(next_subtypes))
    }
  }
  let new_type_sec = TypeSec::new(new_recs)
  let remapper = ModuleTransformer::new()
    .on_typeidx_evt(fn(_, _, tidx : TypeIdx) {
      match tidx {
        TypeIdx(i) => {
          let raw = i.reinterpret_as_int()
          match old_to_new.get(raw) {
            Some(next) =>
              if next == tidx {
                unchanged()
              } else {
                change((), next)
              }
            None => unchanged()
          }
        }
        RecIdx(_) => unchanged()
      }
    })
    .on_heaptype_evt(fn(_, _, ht : HeapType) {
      match ht {
        HeapType(type_idx) =>
          match type_idx {
            TypeIdx(i) => {
              let raw = i.reinterpret_as_int()
              match old_to_new.get(raw) {
                Some(next) =>
                  if next == type_idx {
                    unchanged()
                  } else {
                    change((), HeapType::new(next))
                  }
                None => unchanged()
              }
            }
            RecIdx(_) => unchanged()
          }
        _ => unchanged()
      }
    })
    .on_typesec_evt(fn(_, _, _) { change((), new_type_sec) })
  match remapper.walk_module((), mod) {
    Ok(Some((_, out))) => Ok(out)
    Ok(None) => Ok(mod.with_type_sec(new_type_sec))
    Err(e) => Err(e)
  }
}

///|
fn run_reorder_types(mod : Module, for_testing? : Bool = false) -> Module {
  match reorder_types(mod, for_testing~) {
    Ok(out) => out
    Err(_) => mod
  }
}

///|
test "reorder_types reorders private rec-group members and remaps TypeIdx uses" {
  let private_group = RecType::group([
    SubType::comp_type(
      CompType::struct_([
        FieldType::new(
          StorageType::val_type(
            ValType::ref_type(
              RefType::new(true, HeapType::new(TypeIdx::rec(2))),
            ),
          ),
          Const,
        ),
      ]),
    ),
    SubType::comp_type(CompType::struct_([])),
    SubType::comp_type(CompType::struct_([])),
  ])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([private_group, rt_single_void_type()]))
    .with_func_sec(FuncSec::new([TypeIdx::new(3)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(TInstr::struct_new(TypeIdx::new(1), [])),
            TInstr::drop(TInstr::struct_new(TypeIdx::new(1), [])),
          ]),
        ),
      ]),
    )
  let out = run_reorder_types(mod, for_testing=true)
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
                    { kind: TInstrKind::TStructNew(TypeIdx(i0), []), .. }
                  ),
                  ..,
                },
                ..,
              ],
              ..,
            }
          ),
        ]
      )
    ) => assert_eq(i0, 0U)
    _ => fail("expected first struct.new to be remapped to the first slot")
  }
}

///|
test "reorder_types does not reorder public rec groups" {
  let public_group = RecType::group([
    SubType::comp_type(CompType::struct_([])),
    SubType::comp_type(CompType::struct_([])),
  ])
  let mod = Module::new()
    .with_type_sec(TypeSec::new([public_group, rt_single_void_type()]))
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
            Instruction::i32_const(I32(0)),
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
    .with_func_sec(FuncSec::new([TypeIdx::new(2)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([TInstr::drop(TInstr::struct_new(TypeIdx::new(1), []))]),
        ),
      ]),
    )
  let out = run_reorder_types(mod, for_testing=true)
  assert_eq(out, mod)
}
