///|
priv struct TFFlatTypes {
  subtypes : Array[SubType]
  group_starts : Array[Int]
  groups : Array[Array[Int]]
  type_to_group : Array[Int]
}

///|
fn tf_flatten_types(type_sec : TypeSec) -> TFFlatTypes {
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
fn tf_resolve_type_idx(
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
fn tf_collect_valtype_refs(
  out : Array[Int],
  vt : ValType,
  group_start : Int,
  total : Int,
) -> Unit {
  match vt {
    RefTypeValType(rt) =>
      match rt {
        HeapTypeRefType(_, HeapType(type_idx)) =>
          match tf_resolve_type_idx(type_idx, group_start, total) {
            Some(idx) => out.push(idx)
            None => ()
          }
        _ => ()
      }
    _ => ()
  }
}

///|
fn tf_collect_storage_refs(
  out : Array[Int],
  st : StorageType,
  group_start : Int,
  total : Int,
) -> Unit {
  match st {
    ValTypeStorageType(vt) =>
      tf_collect_valtype_refs(out, vt, group_start, total)
    _ => ()
  }
}

///|
fn tf_collect_subtype_refs(
  subtype : SubType,
  group_start : Int,
  total : Int,
) -> Array[Int] {
  let out : Array[Int] = []
  for super_idx in subtype.super_types() {
    match tf_resolve_type_idx(super_idx, group_start, total) {
      Some(idx) => out.push(idx)
      None => ()
    }
  }
  match subtype.get_comptype() {
    FuncCompType(params, results) => {
      for p in params {
        tf_collect_valtype_refs(out, p, group_start, total)
      }
      for r in results {
        tf_collect_valtype_refs(out, r, group_start, total)
      }
    }
    StructCompType(fields) =>
      for field in fields {
        let FieldType(st, _) = field
        tf_collect_storage_refs(out, st, group_start, total)
      }
    ArrayCompType(field) => {
      let FieldType(st, _) = field
      tf_collect_storage_refs(out, st, group_start, total)
    }
  }
  out
}

///|
fn tf_collect_func_type_idx_by_func(mod : Module) -> Map[FuncIdx, TypeIdx] {
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
fn tf_collect_all_global_types(mod : Module) -> Array[GlobalType] {
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
fn tf_collect_all_table_types(mod : Module) -> Array[TableType] {
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
fn tf_collect_all_tag_types(mod : Module) -> Array[TagType] {
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
fn tf_mark_public_type(
  public_types : Set[Int],
  flat : TFFlatTypes,
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
      ref_ in tf_collect_subtype_refs(
        flat.subtypes[curr],
        flat.group_starts[curr],
        flat.subtypes.length(),
      ) {
      stack.push(ref_)
    }
  }
}

///|
fn tf_mark_public_valtype(
  public_types : Set[Int],
  flat : TFFlatTypes,
  vt : ValType,
) -> Unit {
  match vt {
    RefTypeValType(HeapTypeRefType(_, HeapType(type_idx))) =>
      match tf_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
        Some(idx) => tf_mark_public_type(public_types, flat, idx)
        None => ()
      }
    _ => ()
  }
}

///|
fn tf_mark_public_reftype(
  public_types : Set[Int],
  flat : TFFlatTypes,
  rt : RefType,
) -> Unit {
  match rt {
    HeapTypeRefType(_, HeapType(type_idx)) =>
      match tf_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
        Some(idx) => tf_mark_public_type(public_types, flat, idx)
        None => ()
      }
    _ => ()
  }
}

///|
fn tf_collect_public_types(mod : Module, flat : TFFlatTypes) -> Set[Int] {
  let public_types : Set[Int] = Set::new()
  let func_types = tf_collect_func_type_idx_by_func(mod)
  let global_types = tf_collect_all_global_types(mod)
  let table_types = tf_collect_all_table_types(mod)
  let tag_types = tf_collect_all_tag_types(mod)

  match mod.import_sec {
    Some(ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          Import(_, _, FuncExternType(type_idx)) =>
            match tf_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
              Some(idx) => tf_mark_public_type(public_types, flat, idx)
              None => ()
            }
          Import(_, _, TagExternType(TagType(type_idx))) =>
            match tf_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
              Some(idx) => tf_mark_public_type(public_types, flat, idx)
              None => ()
            }
          Import(_, _, GlobalExternType(GlobalType(vt, _))) =>
            tf_mark_public_valtype(public_types, flat, vt)
          Import(_, _, TableExternType(TableType(rt, _))) =>
            tf_mark_public_reftype(public_types, flat, rt)
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
                match tf_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
                  Some(idx) => tf_mark_public_type(public_types, flat, idx)
                  None => ()
                }
              None => ()
            }
          GlobalExternIdx(GlobalIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < global_types.length() {
              let GlobalType(vt, _) = global_types[idx]
              tf_mark_public_valtype(public_types, flat, vt)
            }
          }
          TableExternIdx(TableIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < table_types.length() {
              let TableType(rt, _) = table_types[idx]
              tf_mark_public_reftype(public_types, flat, rt)
            }
          }
          TagExternIdx(TagIdx(raw)) => {
            let idx = raw.reinterpret_as_int()
            if idx >= 0 && idx < tag_types.length() {
              let TagType(type_idx) = tag_types[idx]
              match tf_resolve_type_idx(type_idx, 0, flat.subtypes.length()) {
                Some(type_i) => tf_mark_public_type(public_types, flat, type_i)
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
fn tf_rebuild_type_sec(
  flat : TFFlatTypes,
  next_subtypes : Array[SubType],
) -> TypeSec {
  let recs : Array[RecType] = []
  for group in flat.groups {
    let rewritten : Array[SubType] = []
    for abs_idx in group {
      rewritten.push(next_subtypes[abs_idx])
    }
    if rewritten.length() == 1 {
      recs.push(RecType::new(rewritten[0]))
    } else {
      recs.push(RecType::group(rewritten))
    }
  }
  TypeSec::new(recs)
}

///|
fn type_finalizing(
  mod : Module,
  finalize? : Bool = true,
) -> Result[Module, String] {
  let type_sec = match mod.type_sec {
    Some(sec) => sec
    None => return Ok(mod)
  }
  let flat = tf_flatten_types(type_sec)
  if flat.subtypes.is_empty() {
    return Ok(mod)
  }

  let public_types = tf_collect_public_types(mod, flat)
  let child_counts : Array[Int] = Array::make(flat.subtypes.length(), 0)
  for idx = 0; idx < flat.subtypes.length(); idx = idx + 1 {
    for super_idx in flat.subtypes[idx].super_types() {
      match
        tf_resolve_type_idx(
          super_idx,
          flat.group_starts[idx],
          flat.subtypes.length(),
        ) {
        Some(super_abs) => child_counts[super_abs] = child_counts[super_abs] + 1
        None => ()
      }
    }
  }

  let next_subtypes = flat.subtypes.copy()
  let mut changed = false
  for idx = 0; idx < next_subtypes.length(); idx = idx + 1 {
    if public_types.contains(idx) {
      continue
    }
    if finalize && child_counts[idx] > 0 {
      continue
    }
    match next_subtypes[idx] {
      SubType(is_final, supers, ct) =>
        if is_final != finalize {
          next_subtypes[idx] = SubType::new(finalize, supers, ct)
          changed = true
        }
      CompTypeSubType(ct) =>
        if !finalize {
          next_subtypes[idx] = SubType::new(false, [], ct)
          changed = true
        }
    }
  }

  if !changed {
    return Ok(mod)
  }
  Ok(mod.with_type_sec(tf_rebuild_type_sec(flat, next_subtypes)))
}

///|
fn type_unfinalizing(mod : Module) -> Result[Module, String] {
  type_finalizing(mod, finalize=false)
}

///|
fn tf_test_flatten_subtypes(mod : Module) -> Array[SubType] {
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
fn tf_test_subtype_at(mod : Module, idx : Int) -> SubType {
  let flat = tf_test_flatten_subtypes(mod)
  if idx < 0 || idx >= flat.length() {
    abort("type index out of bounds in test helper")
  }
  flat[idx]
}

///|
fn tf_test_is_final(st : SubType) -> Bool {
  match st {
    SubType(final_, _, _) => final_
    CompTypeSubType(_) => true
  }
}

///|
fn tf_test_finalize_private_leaf_module() -> Module {
  let root = single_rec_type(sub_type(false, [], struct_comp_type([])))
  let child_a = single_rec_type(
    sub_type(false, [TypeIdx::new(0)], struct_comp_type([])),
  )
  let child_b = single_rec_type(
    sub_type(false, [TypeIdx::new(0)], struct_comp_type([])),
  )
  let public_leaf = single_rec_type(sub_type(false, [], struct_comp_type([])))
  let func_ty = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  Module::new()
  .with_type_sec(TypeSec::new([root, child_a, child_b, public_leaf, func_ty]))
  .with_func_sec(FuncSec::new([TypeIdx::new(4)]))
  .with_code_sec(CodeSec::new([Func::t_func([], TExpr::new([TInstr::nop()]))]))
  .with_global_sec(
    GlobalSec::new([
      Global::new(
        GlobalType::new(
          ValType::ref_null(HeapType::new(TypeIdx::new(3))),
          false,
        ),
        Expr::new([Instruction::ref_null(HeapType::new(TypeIdx::new(3)))]),
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
fn tf_test_unfinalize_private_module() -> Module {
  let public_final = single_rec_type(comp_type_sub_type(struct_comp_type([])))
  let private_final_a = single_rec_type(
    comp_type_sub_type(struct_comp_type([])),
  )
  let private_final_b = single_rec_type(
    sub_type(true, [], struct_comp_type([])),
  )
  let func_ty = single_rec_type(comp_type_sub_type(func_comp_type([], [])))
  Module::new()
  .with_type_sec(
    TypeSec::new([public_final, private_final_a, private_final_b, func_ty]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(3)]))
  .with_code_sec(CodeSec::new([Func::t_func([], TExpr::new([TInstr::nop()]))]))
  .with_global_sec(
    GlobalSec::new([
      Global::new(
        GlobalType::new(
          ValType::ref_null(HeapType::new(TypeIdx::new(0))),
          false,
        ),
        Expr::new([Instruction::ref_null(HeapType::new(TypeIdx::new(0)))]),
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
test "type_finalizing finalizes private leaf types only" {
  let mod = tf_test_finalize_private_leaf_module()
  let out = match type_finalizing(mod, finalize=true) {
    Ok(m) => m
    Err(e) => fail("unexpected type_finalizing error: \{e}")
  }
  let t0 = tf_test_subtype_at(out, 0)
  let t1 = tf_test_subtype_at(out, 1)
  let t2 = tf_test_subtype_at(out, 2)
  let t3 = tf_test_subtype_at(out, 3)
  assert_false(tf_test_is_final(t0))
  assert_true(tf_test_is_final(t1))
  assert_true(tf_test_is_final(t2))
  assert_false(tf_test_is_final(t3))
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("expected finalized module to validate: \{e}")
  }
}

///|
test "type_unfinalizing unfinalizes private final types and keeps public finals" {
  let mod = tf_test_unfinalize_private_module()
  let out = match type_unfinalizing(mod) {
    Ok(m) => m
    Err(e) => fail("unexpected type_unfinalizing error: \{e}")
  }
  let t0 = tf_test_subtype_at(out, 0)
  let t1 = tf_test_subtype_at(out, 1)
  let t2 = tf_test_subtype_at(out, 2)
  match t0 {
    CompTypeSubType(_) => ()
    _ => fail("expected public final type to remain unchanged")
  }
  assert_false(tf_test_is_final(t1))
  assert_false(tf_test_is_final(t2))
  match validate_module(out) {
    Ok(_) => ()
    Err(e) => fail("expected unfinalized module to validate: \{e}")
  }
}
