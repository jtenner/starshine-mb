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
priv struct RUTFlatTypes {
  subtypes : Array[SubType]
  group_starts : Array[Int]
  groups : Array[Array[Int]]
}

///|
fn rut_typeidx_raw(type_idx : TypeIdx) -> Int {
  match type_idx {
    TypeIdx(i) => i.reinterpret_as_int()
    RecIdx(i) => i.reinterpret_as_int()
  }
}

///|
fn rut_resolve_type_idx(
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
fn rut_flatten_types(type_sec : TypeSec) -> RUTFlatTypes {
  let TypeSec(recs) = type_sec
  let subtypes : Array[SubType] = []
  let group_starts : Array[Int] = []
  let groups : Array[Array[Int]] = []
  let mut next = 0
  for rec in recs {
    match rec {
      SingleRecType(st) => {
        subtypes.push(st)
        group_starts.push(next)
        groups.push([next])
        next += 1
      }
      GroupRecType(sts) => {
        let start = next
        let group : Array[Int] = []
        for st in sts {
          subtypes.push(st)
          group_starts.push(start)
          group.push(next)
          next += 1
        }
        groups.push(group)
      }
    }
  }
  { subtypes, group_starts, groups }
}

///|
fn rut_mark_typeidx(roots : Set[Int], type_idx : TypeIdx) -> Unit {
  let raw = rut_typeidx_raw(type_idx)
  if raw >= 0 {
    roots.add(raw)
  }
}

///|
fn rut_mark_heaptype(roots : Set[Int], ht : HeapType) -> Unit {
  match ht {
    HeapType(type_idx) => rut_mark_typeidx(roots, type_idx)
    _ => ()
  }
}

///|
fn rut_mark_module_roots(mod : Module) -> Set[Int] {
  let roots : Set[Int] = Set::new()
  let walker = ModuleTransformer::new()
    .on_typeidx_evt(fn(_, _, tidx) {
      rut_mark_typeidx(roots, tidx)
      unchanged()
    })
    .on_heaptype_evt(fn(_, _, ht) {
      rut_mark_heaptype(roots, ht)
      unchanged()
    })
    .on_tinstruction_evt(fn(self, _, instr) {
      match instr {
        TRefTestDesc(_, ht, _) | TRefCastDescEq(_, ht, _) =>
          rut_mark_heaptype(roots, ht)
        _ => ()
      }
      self.walk_tinstruction_default((), instr)
    })
    .on_instruction_evt(fn(self, _, instr) {
      match instr {
        RefTestDesc(_, ht) | RefCastDescEq(_, ht) =>
          rut_mark_heaptype(roots, ht)
        _ => ()
      }
      self.walk_instruction_default((), instr)
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
  roots
}

///|
fn rut_collect_valtype_refs(
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
              match rut_resolve_type_idx(type_idx, group_start, total) {
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
fn rut_collect_storage_refs(
  out : Array[Int],
  st : StorageType,
  group_start : Int,
  total : Int,
) -> Unit {
  match st {
    ValTypeStorageType(vt) =>
      rut_collect_valtype_refs(out, vt, group_start, total)
    _ => ()
  }
}

///|
fn rut_collect_subtype_refs(
  subtype : SubType,
  group_start : Int,
  total : Int,
) -> Array[Int] {
  let out : Array[Int] = []
  for super_idx in subtype.super_types() {
    match rut_resolve_type_idx(super_idx, group_start, total) {
      Some(idx) => out.push(idx)
      None => ()
    }
  }
  match subtype.get_comptype() {
    FuncCompType(params, results) => {
      for p in params {
        rut_collect_valtype_refs(out, p, group_start, total)
      }
      for r in results {
        rut_collect_valtype_refs(out, r, group_start, total)
      }
    }
    StructCompType(fields) =>
      for field in fields {
        let FieldType(st, _) = field
        rut_collect_storage_refs(out, st, group_start, total)
      }
    ArrayCompType(field) => {
      let FieldType(st, _) = field
      rut_collect_storage_refs(out, st, group_start, total)
    }
  }
  out
}

///|
fn rut_collect_used_types(flat : RUTFlatTypes, roots : Set[Int]) -> Set[Int] {
  let total = flat.subtypes.length()
  let used : Set[Int] = Set::new()
  let stack : Array[Int] = []
  for root in roots {
    if root >= 0 && root < total {
      stack.push(root)
    }
  }
  while !stack.is_empty() {
    let curr = stack.pop().unwrap()
    if used.contains(curr) {
      continue
    }
    used.add(curr)
    let refs = rut_collect_subtype_refs(
      flat.subtypes[curr],
      flat.group_starts[curr],
      total,
    )
    for ref_ in refs {
      if !used.contains(ref_) {
        stack.push(ref_)
      }
    }
  }
  used
}

///|
fn rut_rewrite_typeidx(
  type_idx : TypeIdx,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  old_to_new : Map[Int, TypeIdx],
) -> Result[TypeIdx, String] {
  match rut_resolve_type_idx(type_idx, group_start, total) {
    Some(abs_idx) =>
      match local_pos_by_old.get(abs_idx) {
        Some(pos) => Ok(TypeIdx::rec(pos.reinterpret_as_uint()))
        None =>
          match old_to_new.get(abs_idx) {
            Some(next_idx) => Ok(next_idx)
            None => Err("remove_unused_types: missing remap")
          }
      }
    None => Ok(type_idx)
  }
}

///|
fn rut_rewrite_heaptype(
  ht : HeapType,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  old_to_new : Map[Int, TypeIdx],
) -> Result[HeapType, String] {
  match ht {
    HeapType(type_idx) =>
      match
        rut_rewrite_typeidx(
          type_idx, group_start, total, local_pos_by_old, old_to_new,
        ) {
        Ok(next_idx) => Ok(HeapType::new(next_idx))
        Err(e) => Err(e)
      }
    _ => Ok(ht)
  }
}

///|
fn rut_rewrite_reftype(
  rt : RefType,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  old_to_new : Map[Int, TypeIdx],
) -> Result[RefType, String] {
  match rt {
    HeapTypeRefType(nullable, ht) =>
      match
        rut_rewrite_heaptype(
          ht, group_start, total, local_pos_by_old, old_to_new,
        ) {
        Ok(next_ht) => Ok(RefType::new(nullable, next_ht))
        Err(e) => Err(e)
      }
    _ => Ok(rt)
  }
}

///|
fn rut_rewrite_valtype(
  vt : ValType,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  old_to_new : Map[Int, TypeIdx],
) -> Result[ValType, String] {
  match vt {
    RefTypeValType(rt) =>
      match
        rut_rewrite_reftype(
          rt, group_start, total, local_pos_by_old, old_to_new,
        ) {
        Ok(next_rt) => Ok(ValType::ref_type(next_rt))
        Err(e) => Err(e)
      }
    _ => Ok(vt)
  }
}

///|
fn rut_rewrite_storage(
  st : StorageType,
  group_start : Int,
  total : Int,
  local_pos_by_old : Map[Int, Int],
  old_to_new : Map[Int, TypeIdx],
) -> Result[StorageType, String] {
  match st {
    ValTypeStorageType(vt) =>
      match
        rut_rewrite_valtype(
          vt, group_start, total, local_pos_by_old, old_to_new,
        ) {
        Ok(next_vt) => Ok(StorageType::val_type(next_vt))
        Err(e) => Err(e)
      }
    _ => Ok(st)
  }
}

///|
fn rut_rewrite_subtype(
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
          rut_rewrite_typeidx(
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
              rut_rewrite_valtype(
                p, group_start, total, local_pos_by_old, old_to_new,
              ) {
              Ok(v) => next_params.push(v)
              Err(e) => return Err(e)
            }
          }
          for r in results {
            match
              rut_rewrite_valtype(
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
              rut_rewrite_storage(
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
            rut_rewrite_storage(
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
              rut_rewrite_valtype(
                p, group_start, total, local_pos_by_old, old_to_new,
              ) {
              Ok(v) => next_params.push(v)
              Err(e) => return Err(e)
            }
          }
          for r in results {
            match
              rut_rewrite_valtype(
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
              rut_rewrite_storage(
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
            rut_rewrite_storage(
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
fn rut_has_gc_types(flat : RUTFlatTypes) -> Bool {
  for subtype in flat.subtypes {
    match subtype.get_comptype() {
      StructCompType(_) | ArrayCompType(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn remove_unused_types(mod : Module) -> Result[Module, String] {
  let type_sec = match mod.type_sec {
    Some(type_sec) => type_sec
    None => return Ok(mod)
  }
  let flat = rut_flatten_types(type_sec)
  if flat.subtypes.is_empty() || !rut_has_gc_types(flat) {
    return Ok(mod)
  }

  let roots = rut_mark_module_roots(mod)
  let used = rut_collect_used_types(flat, roots)
  if used.length() == flat.subtypes.length() {
    return Ok(mod)
  }

  let old_to_new : Map[Int, TypeIdx] = Map::new()
  let mut next_idx = 0
  let kept_groups : Array[Array[Int]] = []
  for group in flat.groups {
    let kept : Array[Int] = []
    for old_idx in group {
      if used.contains(old_idx) {
        old_to_new[old_idx] = TypeIdx::new(next_idx.reinterpret_as_uint())
        next_idx += 1
        kept.push(old_idx)
      }
    }
    if !kept.is_empty() {
      kept_groups.push(kept)
    }
  }

  let new_recs : Array[RecType] = []
  for kept in kept_groups {
    let local_pos_by_old : Map[Int, Int] = Map::new()
    for i = 0; i < kept.length(); i = i + 1 {
      local_pos_by_old[kept[i]] = i
    }
    let next_subtypes : Array[SubType] = []
    for old_idx in kept {
      match
        rut_rewrite_subtype(
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
            Some(next) => change((), next)
            None => unchanged()
          }
        }
        RecIdx(_) => unchanged()
      }
    })
    .on_heaptype_evt(fn(_, _, ht : HeapType) {
      match ht {
        HeapType(type_idx) => {
          let next_type = match type_idx {
            TypeIdx(i) => {
              let raw = i.reinterpret_as_int()
              match old_to_new.get(raw) {
                Some(next) => next
                None => type_idx
              }
            }
            RecIdx(_) => type_idx
          }
          change((), HeapType::new(next_type))
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
fn run_remove_unused_types(mod : Module) -> Module {
  match remove_unused_types(mod) {
    Ok(out) => out
    Err(_) => mod
  }
}

///|
fn rut_single_void_type() -> RecType {
  single_rec_type(comp_type_sub_type(func_comp_type([], [])))
}

///|
test "remove_unused_types drops unreachable GC type" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        rut_single_void_type(),
        single_rec_type(comp_type_sub_type(struct_comp_type([]))),
      ]),
    )
    .with_func_sec(FuncSec::new([TypeIdx::new(0)]))
    .with_code_sec(
      CodeSec::new([Func::t_func([], TExpr::new([TInstr::nop()]))]),
    )
  let out = run_remove_unused_types(mod)
  match out.type_sec {
    Some(TypeSec(recs)) => assert_eq(recs.length(), 1)
    None => fail("expected type section")
  }
}

///|
test "remove_unused_types keeps transitive type dependencies" {
  let ty0 = single_rec_type(
    comp_type_sub_type(
      struct_comp_type([
        FieldType::new(
          StorageType::val_type(
            ValType::ref_type(
              RefType::new(true, HeapType::new(TypeIdx::new(1))),
            ),
          ),
          Var,
        ),
      ]),
    ),
  )
  let ty1 = single_rec_type(comp_type_sub_type(struct_comp_type([])))
  let mod = Module::new()
    .with_type_sec(TypeSec::new([ty0, ty1, rut_single_void_type()]))
    .with_func_sec(FuncSec::new([TypeIdx::new(2)]))
    .with_code_sec(
      CodeSec::new([
        Func::t_func(
          [],
          TExpr::new([
            TInstr::drop(
              TInstr::struct_new(TypeIdx::new(0), [
                TInstr::ref_null(HeapType::new(TypeIdx::new(1))),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let out = run_remove_unused_types(mod)
  match out.type_sec {
    Some(TypeSec(recs)) => assert_eq(recs.length(), 3)
    None => fail("expected type section")
  }
}

///|
test "remove_unused_types remaps references after deletion" {
  let mod = Module::new()
    .with_type_sec(
      TypeSec::new([
        single_rec_type(comp_type_sub_type(struct_comp_type([]))),
        single_rec_type(comp_type_sub_type(struct_comp_type([]))),
        rut_single_void_type(),
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
  let out = run_remove_unused_types(mod)
  match out.type_sec {
    Some(TypeSec(recs)) => assert_eq(recs.length(), 2)
    None => fail("expected type section")
  }
  match out.func_sec {
    Some(FuncSec([TypeIdx(1)])) => ()
    _ => fail("expected func type index remap")
  }
  match out.code_sec {
    Some(
      CodeSec([TFunc(_, { instrs: [TDrop(TStructNew(TypeIdx(0), []))], .. })])
    ) => ()
    _ => fail("expected struct.new type index remap")
  }
}
