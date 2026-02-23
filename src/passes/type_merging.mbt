///|
let tm_root_super = -1

///|
let tm_max_iterations = 20

///|
priv struct TMFlatTypes {
  subtypes : Array[SubType]
  group_starts : Array[Int]
  groups : Array[Array[Int]]
  type_to_group : Array[Int]
}

///|
fn tm_flatten_types(type_sec : TypeSec) -> TMFlatTypes {
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
fn tm_resolve_type_idx(
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
fn tm_collect_valtype_refs(
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
              match tm_resolve_type_idx(type_idx, group_start, total) {
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
fn tm_collect_storage_refs(
  out : Array[Int],
  st : StorageType,
  group_start : Int,
  total : Int,
) -> Unit {
  match st {
    ValTypeStorageType(vt) =>
      tm_collect_valtype_refs(out, vt, group_start, total)
    _ => ()
  }
}

///|
fn tm_collect_subtype_refs(
  subtype : SubType,
  group_start : Int,
  total : Int,
) -> Array[Int] {
  let out : Array[Int] = []
  for super_idx in subtype.super_types() {
    match tm_resolve_type_idx(super_idx, group_start, total) {
      Some(idx) => out.push(idx)
      None => ()
    }
  }
  match subtype.get_comptype() {
    FuncCompType(params, results) => {
      for p in params {
        tm_collect_valtype_refs(out, p, group_start, total)
      }
      for r in results {
        tm_collect_valtype_refs(out, r, group_start, total)
      }
    }
    StructCompType(fields) =>
      for field in fields {
        let FieldType(st, _) = field
        tm_collect_storage_refs(out, st, group_start, total)
      }
    ArrayCompType(field) => {
      let FieldType(st, _) = field
      tm_collect_storage_refs(out, st, group_start, total)
    }
  }
  out
}

///|
fn tm_collect_func_type_idx_by_func(mod : Module) -> Map[FuncIdx, TypeIdx] {
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
fn tm_collect_all_global_types(mod : Module) -> Array[GlobalType] {
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
fn tm_collect_all_table_types(mod : Module) -> Array[TableType] {
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
fn tm_collect_all_tag_types(mod : Module) -> Array[TagType] {
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
fn tm_mark_public_type(
  public_types : Set[Int],
  flat : TMFlatTypes,
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
      ref_ in tm_collect_subtype_refs(
        flat.subtypes[curr],
        flat.group_starts[curr],
        flat.subtypes.length(),
      ) {
      stack.push(ref_)
    }
  }
}

///|
fn tm_mark_public_valtype(
  public_types : Set[Int],
  flat : TMFlatTypes,
  vt : ValType,
) -> Unit {
  match vt {
    RefTypeValType(HeapTypeRefType(_, HeapType(type_idx))) =>
      match tm_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
        Some(idx) => tm_mark_public_type(public_types, flat, idx)
        None => ()
      }
    _ => ()
  }
}

///|
fn tm_mark_public_reftype(
  public_types : Set[Int],
  flat : TMFlatTypes,
  rt : RefType,
) -> Unit {
  match rt {
    HeapTypeRefType(_, HeapType(type_idx)) =>
      match tm_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
        Some(idx) => tm_mark_public_type(public_types, flat, idx)
        None => ()
      }
    _ => ()
  }
}

///|
fn tm_collect_public_types(mod : Module, flat : TMFlatTypes) -> Set[Int] {
  let public_types : Set[Int] = Set::new()
  let func_types = tm_collect_func_type_idx_by_func(mod)
  let global_types = tm_collect_all_global_types(mod)
  let table_types = tm_collect_all_table_types(mod)
  let tag_types = tm_collect_all_tag_types(mod)

  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(type_idx)) =>
            match tm_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
              Some(idx) => tm_mark_public_type(public_types, flat, idx)
              None => ()
            }
          Import(_, _, TagExternType(TagType(type_idx))) =>
            match tm_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
              Some(idx) => tm_mark_public_type(public_types, flat, idx)
              None => ()
            }
          Import(_, _, GlobalExternType(GlobalType(vt, _))) =>
            tm_mark_public_valtype(public_types, flat, vt)
          Import(_, _, TableExternType(TableType(rt, _))) =>
            tm_mark_public_reftype(public_types, flat, rt)
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
                match tm_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
                  Some(idx) => tm_mark_public_type(public_types, flat, idx)
                  None => ()
                }
              None => ()
            }
          GlobalExternIdx(GlobalIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < global_types.length() {
              let GlobalType(vt, _) = global_types[idx]
              tm_mark_public_valtype(public_types, flat, vt)
            }
          }
          TableExternIdx(TableIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < table_types.length() {
              let TableType(rt, _) = table_types[idx]
              tm_mark_public_reftype(public_types, flat, rt)
            }
          }
          TagExternIdx(TagIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < tag_types.length() {
              let TagType(type_idx) = tag_types[idx]
              match tm_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
                Some(type_i) => tm_mark_public_type(public_types, flat, type_i)
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
priv struct TMCastInfo {
  cast_types : Set[Int]
  exact_cast_types : Set[Int]
}

///|
fn tm_mark_cast_typeidx(
  cast_types : Set[Int],
  type_idx : TypeIdx,
  group_start : Int,
  total : Int,
) -> Unit {
  match tm_resolve_type_idx(type_idx, group_start, total) {
    Some(idx) => cast_types.add(idx)
    None => ()
  }
}

///|
fn tm_mark_exact_cast_typeidx(
  exact_cast_types : Set[Int],
  type_idx : TypeIdx,
  group_start : Int,
  total : Int,
) -> Unit {
  match tm_resolve_type_idx(type_idx, group_start, total) {
    Some(idx) => exact_cast_types.add(idx)
    None => ()
  }
}

///|
fn tm_mark_cast_heaptype(
  cast_types : Set[Int],
  heap_type : HeapType,
  total : Int,
) -> Unit {
  match heap_type {
    HeapType(type_idx) => tm_mark_cast_typeidx(cast_types, type_idx, 0, total)
    _ => ()
  }
}

///|
fn tm_mark_exact_cast_heaptype(
  exact_cast_types : Set[Int],
  heap_type : HeapType,
  total : Int,
) -> Unit {
  match heap_type {
    HeapType(type_idx) =>
      tm_mark_exact_cast_typeidx(exact_cast_types, type_idx, 0, total)
    _ => ()
  }
}

///|
fn tm_br_on_cast_has_exact_flag(exact_flag : Bool) -> Bool {
  exact_flag
}

///|
fn tm_collect_cast_types(
  mod : Module,
  total : Int,
  traps_never_happen : Bool,
) -> TMCastInfo {
  let cast_types : Set[Int] = Set::new()
  let exact_cast_types : Set[Int] = Set::new()
  let walker = ModuleTransformer::new()
    .on_tinstruction_evt(fn(_, _, instr : TInstr) {
      match instr {
        TRefCast(_, heap_type, _) | TRefTest(_, heap_type, _) =>
          tm_mark_cast_heaptype(cast_types, heap_type, total)
        TRefTestDesc(_, heap_type, _) | TRefCastDescEq(_, heap_type, _) => {
          tm_mark_cast_heaptype(cast_types, heap_type, total)
          tm_mark_exact_cast_heaptype(exact_cast_types, heap_type, total)
        }
        TBrOnCast(_, cast_op, _, target_ht, _, _)
        | TBrOnCastFail(_, cast_op, _, target_ht, _, _) => {
          tm_mark_cast_heaptype(cast_types, target_ht, total)
          if tm_br_on_cast_has_exact_flag(cast_op.1) {
            tm_mark_exact_cast_heaptype(exact_cast_types, target_ht, total)
          }
        }
        TCallIndirect(type_idx, _, _, _)
        | TReturnCallIndirect(type_idx, _, _, _) =>
          if !traps_never_happen {
            tm_mark_cast_typeidx(cast_types, type_idx, 0, total)
          }
        _ => ()
      }
      unchanged()
    })
    .on_instruction_evt(fn(_, _, instr : Instruction) {
      match instr {
        RefCast(_, heap_type) | RefTest(_, heap_type) =>
          tm_mark_cast_heaptype(cast_types, heap_type, total)
        RefTestDesc(_, heap_type) | RefCastDescEq(_, heap_type) => {
          tm_mark_cast_heaptype(cast_types, heap_type, total)
          tm_mark_exact_cast_heaptype(exact_cast_types, heap_type, total)
        }
        BrOnCast(_, cast_op, _, target_ht)
        | BrOnCastFail(_, cast_op, _, target_ht) => {
          tm_mark_cast_heaptype(cast_types, target_ht, total)
          if tm_br_on_cast_has_exact_flag(cast_op.1) {
            tm_mark_exact_cast_heaptype(exact_cast_types, target_ht, total)
          }
        }
        CallIndirect(type_idx, _) | ReturnCallIndirect(type_idx, _) =>
          if !traps_never_happen {
            tm_mark_cast_typeidx(cast_types, type_idx, 0, total)
          }
        _ => ()
      }
      unchanged()
    })
  ignore(walker.walk_module((), mod))
  { cast_types, exact_cast_types }
}

///|
fn tm_get_rep(merges : Map[Int, Int], idx : Int) -> Int {
  let mut curr = idx
  let seen : Array[Int] = []
  while true {
    match merges.get(curr) {
      Some(next) => {
        if next == curr {
          break
        }
        seen.push(curr)
        curr = next
      }
      None => break
    }
  }
  for node in seen {
    merges[node] = curr
  }
  curr
}

///|
fn tm_subtype_is_final(subtype : SubType) -> Bool {
  match subtype {
    SubType(final_, _, _) => final_
    CompTypeSubType(_) => true
  }
}

///|
fn tm_heaptype_shape_eq(
  a : HeapType,
  a_group_start : Int,
  b : HeapType,
  b_group_start : Int,
  total : Int,
  merges : Map[Int, Int],
) -> Bool {
  match (a, b) {
    (AbsHeapTypeHeapType(abs_a), AbsHeapTypeHeapType(abs_b)) => abs_a == abs_b
    (HeapType(a_idx), HeapType(b_idx)) =>
      match
        (
          tm_resolve_type_idx(a_idx, a_group_start, total),
          tm_resolve_type_idx(b_idx, b_group_start, total),
        ) {
        (Some(a_abs), Some(b_abs)) =>
          tm_get_rep(merges, a_abs) == tm_get_rep(merges, b_abs)
        _ => a_idx == b_idx
      }
    (DefTypeHeapType(a_def), DefTypeHeapType(b_def)) => a_def == b_def
    _ => false
  }
}

///|
fn tm_reftype_shape_eq(
  a : RefType,
  a_group_start : Int,
  b : RefType,
  b_group_start : Int,
  total : Int,
  merges : Map[Int, Int],
) -> Bool {
  match (a, b) {
    (HeapTypeRefType(a_nullable, a_ht), HeapTypeRefType(b_nullable, b_ht)) =>
      a_nullable == b_nullable &&
      tm_heaptype_shape_eq(
        a_ht, a_group_start, b_ht, b_group_start, total, merges,
      )
    (AbsHeapTypeRefType(a_ht), AbsHeapTypeRefType(b_ht)) => a_ht == b_ht
    _ => false
  }
}

///|
fn tm_valtype_shape_eq(
  a : ValType,
  a_group_start : Int,
  b : ValType,
  b_group_start : Int,
  total : Int,
  merges : Map[Int, Int],
) -> Bool {
  match (a, b) {
    (RefTypeValType(a_rt), RefTypeValType(b_rt)) =>
      tm_reftype_shape_eq(
        a_rt, a_group_start, b_rt, b_group_start, total, merges,
      )
    _ => a == b
  }
}

///|
fn tm_storage_shape_eq(
  a : StorageType,
  a_group_start : Int,
  b : StorageType,
  b_group_start : Int,
  total : Int,
  merges : Map[Int, Int],
) -> Bool {
  match (a, b) {
    (PackTypeStorageType(pa), PackTypeStorageType(pb)) => pa == pb
    (ValTypeStorageType(va), ValTypeStorageType(vb)) =>
      tm_valtype_shape_eq(va, a_group_start, vb, b_group_start, total, merges)
    _ => false
  }
}

///|
fn tm_field_shape_eq(
  a : FieldType,
  a_group_start : Int,
  b : FieldType,
  b_group_start : Int,
  total : Int,
  merges : Map[Int, Int],
) -> Bool {
  let FieldType(a_storage, a_mut) = a
  let FieldType(b_storage, b_mut) = b
  a_mut == b_mut &&
  tm_storage_shape_eq(
    a_storage, a_group_start, b_storage, b_group_start, total, merges,
  )
}

///|
fn tm_valtypes_shape_eq(
  a : Array[ValType],
  a_group_start : Int,
  b : Array[ValType],
  b_group_start : Int,
  total : Int,
  merges : Map[Int, Int],
) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i = 0; i < a.length(); i = i + 1 {
    if !tm_valtype_shape_eq(
        a[i],
        a_group_start,
        b[i],
        b_group_start,
        total,
        merges,
      ) {
      return false
    }
  }
  true
}

///|
fn tm_comptype_shape_eq(
  a : CompType,
  a_group_start : Int,
  b : CompType,
  b_group_start : Int,
  total : Int,
  merges : Map[Int, Int],
) -> Bool {
  match (a, b) {
    (FuncCompType(a_params, a_results), FuncCompType(b_params, b_results)) =>
      tm_valtypes_shape_eq(
        a_params, a_group_start, b_params, b_group_start, total, merges,
      ) &&
      tm_valtypes_shape_eq(
        a_results, a_group_start, b_results, b_group_start, total, merges,
      )
    (StructCompType(a_fields), StructCompType(b_fields)) => {
      if a_fields.length() != b_fields.length() {
        return false
      }
      for i = 0; i < a_fields.length(); i = i + 1 {
        if !tm_field_shape_eq(
            a_fields[i],
            a_group_start,
            b_fields[i],
            b_group_start,
            total,
            merges,
          ) {
          return false
        }
      }
      true
    }
    (ArrayCompType(a_field), ArrayCompType(b_field)) =>
      tm_field_shape_eq(
        a_field, a_group_start, b_field, b_group_start, total, merges,
      )
    _ => false
  }
}

///|
fn tm_subtype_shape_eq(
  a_idx : Int,
  b_idx : Int,
  flat : TMFlatTypes,
  merges : Map[Int, Int],
) -> Bool {
  let a = flat.subtypes[a_idx]
  let b = flat.subtypes[b_idx]
  if tm_subtype_is_final(a) != tm_subtype_is_final(b) {
    return false
  }
  tm_comptype_shape_eq(
    a.get_comptype(),
    flat.group_starts[a_idx],
    b.get_comptype(),
    flat.group_starts[b_idx],
    flat.subtypes.length(),
    merges,
  )
}

///|
fn tm_collect_direct_supers(flat : TMFlatTypes) -> Array[Int?] {
  let supers : Array[Int?] = Array::make(flat.subtypes.length(), None)
  for idx = 0; idx < flat.subtypes.length(); idx = idx + 1 {
    let super_types = flat.subtypes[idx].super_types()
    if super_types.length() != 1 {
      continue
    }
    match
      tm_resolve_type_idx(
        super_types[0],
        flat.group_starts[idx],
        flat.subtypes.length(),
      ) {
      Some(super_idx) => supers[idx] = Some(super_idx)
      None => ()
    }
  }
  supers
}

///|
fn tm_heaptype_shallow_eq(a : HeapType, b : HeapType) -> Bool {
  match (a, b) {
    (AbsHeapTypeHeapType(abs_a), AbsHeapTypeHeapType(abs_b)) => abs_a == abs_b
    (HeapType(_), HeapType(_)) => true
    (DefTypeHeapType(def_a), DefTypeHeapType(def_b)) => def_a == def_b
    _ => false
  }
}

///|
fn tm_reftype_shallow_eq(a : RefType, b : RefType) -> Bool {
  match (a, b) {
    (HeapTypeRefType(a_nullable, a_ht), HeapTypeRefType(b_nullable, b_ht)) =>
      a_nullable == b_nullable && tm_heaptype_shallow_eq(a_ht, b_ht)
    (AbsHeapTypeRefType(a_ht), AbsHeapTypeRefType(b_ht)) => a_ht == b_ht
    _ => false
  }
}

///|
fn tm_valtype_shallow_eq(a : ValType, b : ValType) -> Bool {
  match (a, b) {
    (RefTypeValType(a_rt), RefTypeValType(b_rt)) =>
      tm_reftype_shallow_eq(a_rt, b_rt)
    _ => a == b
  }
}

///|
fn tm_storage_shallow_eq(a : StorageType, b : StorageType) -> Bool {
  match (a, b) {
    (PackTypeStorageType(pa), PackTypeStorageType(pb)) => pa == pb
    (ValTypeStorageType(va), ValTypeStorageType(vb)) =>
      tm_valtype_shallow_eq(va, vb)
    _ => false
  }
}

///|
fn tm_field_shallow_eq(a : FieldType, b : FieldType) -> Bool {
  let FieldType(a_storage, a_mut) = a
  let FieldType(b_storage, b_mut) = b
  a_mut == b_mut && tm_storage_shallow_eq(a_storage, b_storage)
}

///|
fn tm_valtypes_shallow_eq(a : Array[ValType], b : Array[ValType]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i = 0; i < a.length(); i = i + 1 {
    if !tm_valtype_shallow_eq(a[i], b[i]) {
      return false
    }
  }
  true
}

///|
fn tm_comptype_shallow_eq(a : CompType, b : CompType) -> Bool {
  match (a, b) {
    (FuncCompType(a_params, a_results), FuncCompType(b_params, b_results)) =>
      tm_valtypes_shallow_eq(a_params, b_params) &&
      tm_valtypes_shallow_eq(a_results, b_results)
    (StructCompType(a_fields), StructCompType(b_fields)) => {
      if a_fields.length() != b_fields.length() {
        return false
      }
      for i = 0; i < a_fields.length(); i = i + 1 {
        if !tm_field_shallow_eq(a_fields[i], b_fields[i]) {
          return false
        }
      }
      true
    }
    (ArrayCompType(a_field), ArrayCompType(b_field)) =>
      tm_field_shallow_eq(a_field, b_field)
    _ => false
  }
}

///|
fn tm_subtype_shallow_eq(a_idx : Int, b_idx : Int, flat : TMFlatTypes) -> Bool {
  let a = flat.subtypes[a_idx]
  let b = flat.subtypes[b_idx]
  if tm_subtype_is_final(a) != tm_subtype_is_final(b) {
    return false
  }
  tm_comptype_shallow_eq(a.get_comptype(), b.get_comptype())
}

///|
fn tm_collect_comptype_heap_children(
  comp_type : CompType,
  group_start : Int,
  total : Int,
) -> Array[Int] {
  let out : Array[Int] = []

  fn collect_heaptype(
    out : Array[Int],
    heap_type : HeapType,
    group_start : Int,
    total : Int,
  ) -> Unit {
    match heap_type {
      HeapType(type_idx) =>
        match tm_resolve_type_idx(type_idx, group_start, total) {
          Some(idx) => out.push(idx)
          None => ()
        }
      _ => ()
    }
  }

  fn collect_reftype(
    out : Array[Int],
    ref_type : RefType,
    group_start : Int,
    total : Int,
  ) -> Unit {
    match ref_type {
      HeapTypeRefType(_, heap_type) =>
        collect_heaptype(out, heap_type, group_start, total)
      _ => ()
    }
  }

  fn collect_valtype(
    out : Array[Int],
    val_type : ValType,
    group_start : Int,
    total : Int,
  ) -> Unit {
    match val_type {
      RefTypeValType(ref_type) =>
        collect_reftype(out, ref_type, group_start, total)
      _ => ()
    }
  }

  fn collect_storage(
    out : Array[Int],
    storage_type : StorageType,
    group_start : Int,
    total : Int,
  ) -> Unit {
    match storage_type {
      ValTypeStorageType(val_type) =>
        collect_valtype(out, val_type, group_start, total)
      _ => ()
    }
  }

  match comp_type {
    FuncCompType(params, results) => {
      for param in params {
        collect_valtype(out, param, group_start, total)
      }
      for result in results {
        collect_valtype(out, result, group_start, total)
      }
    }
    StructCompType(fields) =>
      for field in fields {
        let FieldType(storage, _) = field
        collect_storage(out, storage, group_start, total)
      }
    ArrayCompType(field) => {
      let FieldType(storage, _) = field
      collect_storage(out, storage, group_start, total)
    }
  }
  out
}

///|
fn tm_int_arrays_eq(a : Array[Int], b : Array[Int]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i = 0; i < a.length(); i = i + 1 {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
fn tm_refine_sibling_group(
  group : Array[Int],
  flat : TMFlatTypes,
  merges : Map[Int, Int],
) -> Array[Int] {
  if group.length() <= 1 {
    return [0]
  }

  let group_pos_by_type : Map[Int, Int] = Map::new()
  for pos = 0; pos < group.length(); pos = pos + 1 {
    group_pos_by_type[group[pos]] = pos
  }

  let children_by_pos : Array[Array[Int]] = []
  for type_idx in group {
    let children = tm_collect_comptype_heap_children(
      flat.subtypes[type_idx].get_comptype(),
      flat.group_starts[type_idx],
      flat.subtypes.length(),
    )
    let reps : Array[Int] = []
    for child in children {
      reps.push(tm_get_rep(merges, child))
    }
    children_by_pos.push(reps)
  }

  let colors : Array[Int] = []
  let mut next_color = 0
  for i = 0; i < group.length(); i = i + 1 {
    let mut found : Int? = None
    for j = 0; j < i; j = j + 1 {
      if tm_subtype_shallow_eq(group[i], group[j], flat) {
        found = Some(colors[j])
        break
      }
    }
    match found {
      Some(c) => colors.push(c)
      None => {
        colors.push(next_color)
        next_color += 1
      }
    }
  }

  for _ in 0..<tm_max_iterations {
    let external_color : Map[Int, Int] = Map::new()
    let mut next_external = next_color

    let child_color_sigs : Array[Array[Int]] = []
    for pos = 0; pos < group.length(); pos = pos + 1 {
      let sig : Array[Int] = []
      for child_rep in children_by_pos[pos] {
        match group_pos_by_type.get(child_rep) {
          Some(child_pos) => sig.push(colors[child_pos])
          None =>
            match external_color.get(child_rep) {
              Some(c) => sig.push(c)
              None => {
                external_color[child_rep] = next_external
                sig.push(next_external)
                next_external += 1
              }
            }
        }
      }
      child_color_sigs.push(sig)
    }

    let next_colors : Array[Int] = []
    let mut next_refined = 0
    for i = 0; i < group.length(); i = i + 1 {
      let mut found : Int? = None
      for j = 0; j < i; j = j + 1 {
        if colors[i] == colors[j] &&
          tm_int_arrays_eq(child_color_sigs[i], child_color_sigs[j]) {
          found = Some(next_colors[j])
          break
        }
      }
      match found {
        Some(c) => next_colors.push(c)
        None => {
          next_colors.push(next_refined)
          next_refined += 1
        }
      }
    }

    if tm_int_arrays_eq(colors, next_colors) {
      return colors
    }
    colors.clear()
    for c in next_colors {
      colors.push(c)
    }
    next_color = 0
    for c in colors {
      if c + 1 > next_color {
        next_color = c + 1
      }
    }
  }

  colors
}

///|
fn tm_try_merge_supertypes(
  flat : TMFlatTypes,
  is_private : Array[Bool],
  cast_types : Set[Int],
  exact_cast_types : Set[Int],
  direct_supers : Array[Int?],
  merges : Map[Int, Int],
) -> Bool {
  let mut changed = false
  for idx = 0; idx < flat.subtypes.length(); idx = idx + 1 {
    if !is_private[idx] ||
      cast_types.contains(idx) ||
      tm_get_rep(merges, idx) != idx {
      continue
    }
    match direct_supers[idx] {
      Some(super_idx) => {
        let target = tm_get_rep(merges, super_idx)
        if target != idx &&
          !exact_cast_types.contains(target) &&
          tm_subtype_shape_eq(idx, target, flat, merges) {
          merges[idx] = target
          changed = true
        }
      }
      None => ()
    }
  }
  changed
}

///|
fn tm_try_merge_siblings(
  flat : TMFlatTypes,
  is_private : Array[Bool],
  cast_types : Set[Int],
  direct_supers : Array[Int?],
  merges : Map[Int, Int],
) -> Bool {
  let by_super : Map[Int, Array[Int]] = Map::new()
  for idx = 0; idx < flat.subtypes.length(); idx = idx + 1 {
    if !is_private[idx] ||
      cast_types.contains(idx) ||
      tm_get_rep(merges, idx) != idx {
      continue
    }
    let super_key = match direct_supers[idx] {
      Some(parent) => tm_get_rep(merges, parent)
      None => tm_root_super
    }
    match by_super.get(super_key) {
      Some(group) => group.push(idx)
      None => by_super[super_key] = [idx]
    }
  }

  let super_keys : Array[Int] = []
  for k, _ in by_super {
    super_keys.push(k)
  }
  super_keys.sort()

  let mut changed = false
  for key in super_keys {
    let group = by_super.get(key).unwrap_or([])
    if group.length() <= 1 {
      continue
    }
    let colors = tm_refine_sibling_group(group, flat, merges)
    let target_by_color : Map[Int, Int] = Map::new()
    for i = 0; i < group.length(); i = i + 1 {
      let type_idx = group[i]
      let color = colors[i]
      match target_by_color.get(color) {
        Some(target) =>
          if type_idx != target {
            merges[type_idx] = target
            changed = true
          }
        None => target_by_color[color] = type_idx
      }
    }
  }
  changed
}

///|
fn tm_remap_abs(remap : Map[Int, Int], idx : Int) -> Int {
  match remap.get(idx) {
    Some(next) => next
    None => idx
  }
}

///|
fn tm_rewrite_typeidx(
  type_idx : TypeIdx,
  group_start : Int,
  group_len : Int,
  total : Int,
  remap : Map[Int, Int],
) -> TypeIdx {
  match tm_resolve_type_idx(type_idx, group_start, total) {
    Some(abs_idx) => {
      let mapped = tm_remap_abs(remap, abs_idx)
      if mapped >= group_start && mapped < group_start + group_len {
        TypeIdx::rec((mapped - group_start).reinterpret_as_uint())
      } else {
        TypeIdx::new(mapped.reinterpret_as_uint())
      }
    }
    None => type_idx
  }
}

///|
fn tm_rewrite_heaptype(
  heap_type : HeapType,
  group_start : Int,
  group_len : Int,
  total : Int,
  remap : Map[Int, Int],
) -> HeapType {
  match heap_type {
    HeapType(type_idx) =>
      HeapType::new(
        tm_rewrite_typeidx(type_idx, group_start, group_len, total, remap),
      )
    _ => heap_type
  }
}

///|
fn tm_rewrite_reftype(
  ref_type : RefType,
  group_start : Int,
  group_len : Int,
  total : Int,
  remap : Map[Int, Int],
) -> RefType {
  match ref_type {
    HeapTypeRefType(nullable, heap_type) =>
      RefType::new(
        nullable,
        tm_rewrite_heaptype(heap_type, group_start, group_len, total, remap),
      )
    _ => ref_type
  }
}

///|
fn tm_rewrite_valtype(
  val_type : ValType,
  group_start : Int,
  group_len : Int,
  total : Int,
  remap : Map[Int, Int],
) -> ValType {
  match val_type {
    RefTypeValType(ref_type) =>
      ValType::ref_type(
        tm_rewrite_reftype(ref_type, group_start, group_len, total, remap),
      )
    _ => val_type
  }
}

///|
fn tm_rewrite_storage_type(
  storage_type : StorageType,
  group_start : Int,
  group_len : Int,
  total : Int,
  remap : Map[Int, Int],
) -> StorageType {
  match storage_type {
    ValTypeStorageType(vt) =>
      StorageType::val_type(
        tm_rewrite_valtype(vt, group_start, group_len, total, remap),
      )
    _ => storage_type
  }
}

///|
fn tm_rewrite_field_type(
  field_type : FieldType,
  group_start : Int,
  group_len : Int,
  total : Int,
  remap : Map[Int, Int],
) -> FieldType {
  let FieldType(storage_type, mutability) = field_type
  FieldType::new(
    tm_rewrite_storage_type(storage_type, group_start, group_len, total, remap),
    mutability,
  )
}

///|
fn tm_rewrite_comptype(
  comp_type : CompType,
  group_start : Int,
  group_len : Int,
  total : Int,
  remap : Map[Int, Int],
) -> CompType {
  match comp_type {
    FuncCompType(params, results) => {
      let next_params : Array[ValType] = []
      let next_results : Array[ValType] = []
      for param in params {
        next_params.push(
          tm_rewrite_valtype(param, group_start, group_len, total, remap),
        )
      }
      for result in results {
        next_results.push(
          tm_rewrite_valtype(result, group_start, group_len, total, remap),
        )
      }
      CompType::func(next_params, next_results)
    }
    StructCompType(fields) => {
      let next_fields : Array[FieldType] = []
      for field in fields {
        next_fields.push(
          tm_rewrite_field_type(field, group_start, group_len, total, remap),
        )
      }
      CompType::struct_(next_fields)
    }
    ArrayCompType(field) =>
      CompType::array(
        tm_rewrite_field_type(field, group_start, group_len, total, remap),
      )
  }
}

///|
fn tm_rewrite_subtype(
  subtype : SubType,
  group_start : Int,
  group_len : Int,
  total : Int,
  remap : Map[Int, Int],
) -> SubType {
  match subtype {
    SubType(final_, supers, comp_type) => {
      let next_supers : Array[TypeIdx] = []
      for super_type in supers {
        next_supers.push(
          tm_rewrite_typeidx(super_type, group_start, group_len, total, remap),
        )
      }
      SubType::new(
        final_,
        next_supers,
        tm_rewrite_comptype(comp_type, group_start, group_len, total, remap),
      )
    }
    CompTypeSubType(comp_type) =>
      SubType::comp_type(
        tm_rewrite_comptype(comp_type, group_start, group_len, total, remap),
      )
  }
}

///|
fn tm_rewrite_type_sec(flat : TMFlatTypes, remap : Map[Int, Int]) -> TypeSec {
  let total = flat.subtypes.length()
  let new_recs : Array[RecType] = []
  for group in flat.groups {
    let group_len = group.length()
    let next_subtypes : Array[SubType] = []
    for abs_idx in group {
      next_subtypes.push(
        tm_rewrite_subtype(
          flat.subtypes[abs_idx],
          flat.group_starts[abs_idx],
          group_len,
          total,
          remap,
        ),
      )
    }
    if next_subtypes.length() == 1 {
      new_recs.push(RecType::new(next_subtypes[0]))
    } else {
      new_recs.push(RecType::group(next_subtypes))
    }
  }
  TypeSec::new(new_recs)
}

///|
fn tm_apply_merges(
  mod : Module,
  flat : TMFlatTypes,
  remap : Map[Int, Int],
) -> Result[Module, String] {
  let new_type_sec = tm_rewrite_type_sec(flat, remap)
  let remapper = ModuleTransformer::new()
    .on_typeidx_evt(fn(_, _, type_idx : TypeIdx) {
      match type_idx {
        TypeIdx(i) => {
          let raw = i.reinterpret_as_int()
          let mapped = tm_remap_abs(remap, raw)
          if mapped == raw {
            unchanged()
          } else {
            change((), TypeIdx::new(mapped.reinterpret_as_uint()))
          }
        }
        RecIdx(_) => unchanged()
      }
    })
    .on_heaptype_evt(fn(_, _, heap_type : HeapType) {
      match heap_type {
        HeapType(TypeIdx(i)) => {
          let raw = i.reinterpret_as_int()
          let mapped = tm_remap_abs(remap, raw)
          if mapped == raw {
            unchanged()
          } else {
            change(
              (),
              HeapType::new(TypeIdx::new(mapped.reinterpret_as_uint())),
            )
          }
        }
        _ => unchanged()
      }
    })
    .on_typesec_evt(fn(_, _, _) { change((), new_type_sec) })

  let merged = match remapper.walk_module((), mod) {
    Ok(Some((_, out))) => out
    Ok(None) => mod.with_type_sec(new_type_sec)
    Err(e) => return Err(e)
  }
  remove_unused_types(merged)
}

///|
fn tm_has_gc_types(flat : TMFlatTypes) -> Bool {
  for subtype in flat.subtypes {
    match subtype.get_comptype() {
      StructCompType(_) | ArrayCompType(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn type_merging(
  mod : Module,
  traps_never_happen? : Bool = false,
) -> Result[Module, String] {
  let type_sec = match mod.type_sec {
    Some(sec) => sec
    None => return Ok(mod)
  }
  let flat = tm_flatten_types(type_sec)
  if flat.subtypes.is_empty() || !tm_has_gc_types(flat) {
    return Ok(mod)
  }

  let public_types = tm_collect_public_types(mod, flat)
  let cast_info = tm_collect_cast_types(
    mod,
    flat.subtypes.length(),
    traps_never_happen,
  )
  let cast_types = cast_info.cast_types
  let exact_cast_types = cast_info.exact_cast_types
  let is_private : Array[Bool] = Array::make(flat.subtypes.length(), true)
  for idx in public_types {
    if idx >= 0 && idx < is_private.length() {
      is_private[idx] = false
    }
  }

  let direct_supers = tm_collect_direct_supers(flat)
  let merges : Map[Int, Int] = Map::new()
  ignore(
    tm_try_merge_supertypes(
      flat, is_private, cast_types, exact_cast_types, direct_supers, merges,
    ),
  )
  for i = 0; i < tm_max_iterations; i = i + 1 {
    if !tm_try_merge_siblings(
        flat, is_private, cast_types, direct_supers, merges,
      ) {
      break
    }
  }

  let remap : Map[Int, Int] = Map::new()
  for idx = 0; idx < flat.subtypes.length(); idx = idx + 1 {
    let target = tm_get_rep(merges, idx)
    if target != idx {
      remap[idx] = target
    }
  }
  if remap.is_empty() {
    return Ok(mod)
  }

  tm_apply_merges(mod, flat, remap)
}

///|
fn run_type_merging(mod : Module) -> Module {
  match type_merging(mod) {
    Ok(out) => out
    Err(_) => mod
  }
}

///|
fn tm_open_empty_struct_type(super_types? : Array[TypeIdx] = []) -> RecType {
  single_rec_type(sub_type(false, super_types, struct_comp_type([])))
}

///|
fn tm_open_i32_struct_type(super_types? : Array[TypeIdx] = []) -> RecType {
  single_rec_type(
    sub_type(
      false,
      super_types,
      struct_comp_type([
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  )
}

///|
fn tm_void_func_type() -> RecType {
  single_rec_type(comp_type_sub_type(func_comp_type([], [])))
}

///|
fn tm_total_type_count(mod : Module) -> Int {
  match mod.type_sec {
    Some(TypeSec(recs)) => {
      let mut count = 0
      for rec in recs {
        match rec {
          SingleRecType(_) => count += 1
          GroupRecType(sts) => count += sts.length()
        }
      }
      count
    }
    None => 0
  }
}

///|
fn tm_run_type_merging_with_traps_never_happen(
  mod : Module,
  traps_never_happen : Bool,
) -> Module {
  match type_merging(mod, traps_never_happen~) {
    Ok(out) => out
    Err(_) => mod
  }
}

///|
fn tm_assert_valid_module(mod : Module, label : String) -> Unit raise {
  match validate_module(mod) {
    Ok(_) => ()
    Err(e) => fail("\{label}: expected module to validate: \{e}")
  }
}

///|
fn tm_br_on_cast_exactness_observer(exact : Bool) -> TInstr {
  let super_heap_type = HeapType::new(TypeIdx::new(0))
  TInstr::drop(
    TInstr::block(
      BlockType::val_type(ValType::ref_null(super_heap_type)),
      TExpr::new([
        TInstr::drop(
          TInstr::br_on_cast(
            LabelIdx::new(0),
            true,
            super_heap_type,
            exact,
            super_heap_type,
            TInstr::ref_null(super_heap_type),
            [],
          ),
        ),
        TInstr::ref_null(super_heap_type),
      ]),
    ),
  )
}

///|
fn tm_br_on_cast_exactness_module(exact : Bool) -> Module {
  Module::new()
  .with_type_sec(
    TypeSec::new([
      tm_open_empty_struct_type(),
      tm_open_empty_struct_type(super_types=[TypeIdx::new(0)]),
      tm_void_func_type(),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(2)]))
  .with_code_sec(
    CodeSec::new([
      Func::t_func(
        [],
        TExpr::new([
          TInstr::drop(TInstr::struct_new(TypeIdx::new(1), [])),
          tm_br_on_cast_exactness_observer(exact),
        ]),
      ),
    ]),
  )
}

///|
test "type_merging merges private subtype into identical supertype" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        tm_open_empty_struct_type(),
        tm_open_empty_struct_type(super_types=[TypeIdx::new(0)]),
        tm_void_func_type(),
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
  let out = run_type_merging(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(TStructNew(TypeIdx(0), []))]))])) => ()
    _ => fail("expected identical subtype use-sites to merge to the supertype")
  }
  match out.type_sec {
    Some(TypeSec(recs)) => assert_eq(recs.length(), 2)
    None => fail("expected type section")
  }
}

///|
test "type_merging does not merge cast-target type" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        tm_open_empty_struct_type(),
        tm_open_empty_struct_type(super_types=[TypeIdx::new(0)]),
        tm_void_func_type(),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(2)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(TInstr::struct_new(TypeIdx::new(1), [])),
            TInstr::drop(
              TInstr::ref_test(
                true,
                HeapType::new(TypeIdx::new(1)),
                TInstr::ref_null(HeapType::new(TypeIdx::new(1))),
              ),
            ),
          ]),
        ),
      ]),
    )
  let out = run_type_merging(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(TStructNew(TypeIdx(1), [])), ..]))])) =>
      ()
    _ => fail("expected cast-target subtype to remain distinct")
  }
  match out.type_sec {
    Some(TypeSec(recs)) => assert_eq(recs.length(), 3)
    None => fail("expected type section")
  }
}

///|
test "type_merging merges identical siblings" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        tm_open_empty_struct_type(),
        tm_open_i32_struct_type(super_types=[TypeIdx::new(0)]),
        tm_open_i32_struct_type(super_types=[TypeIdx::new(0)]),
        tm_void_func_type(),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(3)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::struct_new(TypeIdx::new(1), [TInstr::i32_const(I32(1))]),
            ),
            TInstr::drop(
              TInstr::struct_new(TypeIdx::new(2), [TInstr::i32_const(I32(2))]),
            ),
          ]),
        ),
      ]),
    )
  let out = run_type_merging(mod)
  match out.code_sec {
    Some(
      CodeSec(
        [
          TFunc(
            _,
            TExpr(
              [
                TDrop(TStructNew(TypeIdx(lhs), [TI32Const(I32(1))])),
                TDrop(TStructNew(TypeIdx(rhs), [TI32Const(I32(2))])),
              ]
            )
          ),
        ]
      )
    ) => assert_eq(lhs, rhs)
    _ => fail("expected sibling struct uses to share one merged type")
  }
  match out.type_sec {
    Some(TypeSec(recs)) => assert_eq(recs.length(), 3)
    None => fail("expected type section")
  }
}

///|
test "type_merging does not merge public type" {
  let exported_functype = single_rec_type(
    comp_type_sub_type(
      func_comp_type([], [ValType::ref_null(HeapType::new(TypeIdx::new(1)))]),
    ),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        tm_open_empty_struct_type(),
        tm_open_empty_struct_type(super_types=[TypeIdx::new(0)]),
        exported_functype,
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(2)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([TInstr::ref_null(HeapType::new(TypeIdx::new(1)))]),
        ),
      ]),
    )
    .with_export_sec(
      ExportSec::new([
        Export::new(Name::new("f"), ExternIdx::func(FuncIdx::new(0))),
      ]),
    )
  let out = run_type_merging(mod)
  match out.type_sec {
    Some(TypeSec(recs)) => assert_eq(recs.length(), 3)
    None => fail("expected type section")
  }
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TRefNull(HeapType(TypeIdx(1)))]))])) => ()
    _ => fail("expected public type references to remain unchanged")
  }
}

///|
test "type_merging treats call_indirect cast barrier as trap-mode sensitive" {
  let func_super = single_rec_type(sub_type(false, [], func_comp_type([], [])))
  let func_sub = single_rec_type(
    sub_type(false, [TypeIdx::new(1)], func_comp_type([], [])),
  )
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([tm_open_empty_struct_type(), func_super, func_sub]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(1), TypeIdx::new(2)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::call_indirect(
              TypeIdx::new(2),
              TableIdx::new(0),
              [],
              TInstr::i32_const(I32(0)),
            ),
          ]),
        ),
        Func::t_func([], TExpr::new([TInstr::nop()])),
      ]),
    )

  let out_default = tm_run_type_merging_with_traps_never_happen(mod, false)
  match out_default.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TCallIndirect(TypeIdx(2), _, _, _)])), ..])) =>
      ()
    _ => fail("expected call_indirect type to remain when traps may happen")
  }

  let out_tnh = tm_run_type_merging_with_traps_never_happen(mod, true)
  let mut merged_type_idx : UInt? = None
  match out_tnh.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TCallIndirect(TypeIdx(i), _, _, _)])), ..])) =>
      merged_type_idx = Some(i)
    _ => fail("expected call_indirect to remain present after type_merging")
  }
  match (out_tnh.func_sec, merged_type_idx) {
    (Some(FuncSec([TypeIdx(main_i), TypeIdx(callee_i)])), Some(call_i)) => {
      assert_eq(main_i, callee_i)
      assert_eq(call_i, main_i)
      assert_true(call_i != 2U)
    }
    _ =>
      fail(
        "expected call_indirect type to merge to super when traps_never_happen",
      )
  }
}

///|
test "type_merging exact descriptor casts on supertype block subtype merge" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        tm_open_empty_struct_type(),
        tm_open_empty_struct_type(super_types=[TypeIdx::new(0)]),
        tm_void_func_type(),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(2)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(TInstr::struct_new(TypeIdx::new(1), [])),
            TInstr::drop(
              TInstr::ref_test_desc(
                true,
                HeapType::new(TypeIdx::new(0)),
                TInstr::ref_null(HeapType::new(TypeIdx::new(0))),
              ),
            ),
          ]),
        ),
      ]),
    )
  let out = run_type_merging(mod)
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(TStructNew(TypeIdx(1), [])), ..]))])) =>
      ()
    _ =>
      fail("expected subtype to remain distinct due to exact cast on supertype")
  }
}

///|
test "type_merging treats identical br_on_cast source-target as exact cast barrier" {
  let mod = tm_br_on_cast_exactness_module(true)
  tm_assert_valid_module(mod, "br_on_cast exact barrier input")
  let out = run_type_merging(mod)
  tm_assert_valid_module(out, "br_on_cast exact barrier output")
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(TStructNew(TypeIdx(1), [])), ..]))])) =>
      ()
    _ =>
      fail(
        "expected subtype to remain distinct due to exact-equivalent br_on_cast",
      )
  }
}

///|
test "type_merging merges identical br_on_cast source-target without exact flag" {
  let mod = tm_br_on_cast_exactness_module(false)
  tm_assert_valid_module(mod, "br_on_cast non-exact input")
  let out = run_type_merging(mod)
  tm_assert_valid_module(out, "br_on_cast non-exact output")
  match out.code_sec {
    Some(CodeSec([TFunc(_, TExpr([TDrop(TStructNew(TypeIdx(0), [])), ..]))])) =>
      ()
    _ =>
      fail(
        "expected subtype to merge when identical br_on_cast lacks exact flag",
      )
  }
}

///|
test "type_merging merges mutually-recursive sibling shapes via partition refinement" {
  let recursive_group = RecType::group([
    sub_type(
      false,
      [TypeIdx::new(0)],
      struct_comp_type([
        FieldType::new(
          StorageType::val_type(
            ValType::ref_type(
              RefType::new(true, HeapType::new(TypeIdx::rec(2))),
            ),
          ),
          Var,
        ),
      ]),
    ),
    sub_type(
      false,
      [TypeIdx::new(0)],
      struct_comp_type([
        FieldType::new(
          StorageType::val_type(
            ValType::ref_type(
              RefType::new(true, HeapType::new(TypeIdx::rec(3))),
            ),
          ),
          Var,
        ),
      ]),
    ),
    sub_type(
      false,
      [TypeIdx::new(0)],
      struct_comp_type([
        FieldType::new(
          StorageType::val_type(
            ValType::ref_type(
              RefType::new(true, HeapType::new(TypeIdx::rec(0))),
            ),
          ),
          Var,
        ),
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
    sub_type(
      false,
      [TypeIdx::new(0)],
      struct_comp_type([
        FieldType::new(
          StorageType::val_type(
            ValType::ref_type(
              RefType::new(true, HeapType::new(TypeIdx::rec(1))),
            ),
          ),
          Var,
        ),
        FieldType::new(StorageType::val_type(ValType::i32()), Var),
      ]),
    ),
  ])

  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        tm_open_empty_struct_type(),
        recursive_group,
        tm_void_func_type(),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(5)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::struct_new(TypeIdx::new(1), [
                TInstr::ref_null(HeapType::new(TypeIdx::new(3))),
              ]),
            ),
            TInstr::drop(
              TInstr::struct_new(TypeIdx::new(2), [
                TInstr::ref_null(HeapType::new(TypeIdx::new(4))),
              ]),
            ),
          ]),
        ),
      ]),
    )

  let out = run_type_merging(mod)
  assert_eq(tm_total_type_count(out), 4)
}
