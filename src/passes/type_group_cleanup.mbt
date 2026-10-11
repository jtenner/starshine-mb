// Licensing scope: see ../../LICENSE and this directory's LICENSE and NOTICE.
// Potentially incorporated Binaryen expression retains Apache-2.0 terms.
// Original Starshine contributions use the scoped MIT grant in ../../LICENSE.
// Modified for Starshine through 2026: implementation and validation use
// Starshine's representations and APIs; this is not an unchanged upstream file.
// Conservative notice retention does not establish copying or independence.

///|
// An optional encoding cleanup. Whole recursion groups remain indivisible;
// only global indices are renamed, preserving relative recursive identities.
fn pass_cleanup_unused_type_groups(
  mod_ : @lib.Module,
  root_scans? : Array[Int]? = None,
) -> @lib.Module {
  if !mod_.custom_secs.is_empty() {
    return mod_
  }
  let groups = match mod_.type_sec {
    Some(@lib.TypeSec(groups)) => groups
    None => return mod_
  }
  let starts : Array[Int] = []
  let counts : Array[Int] = []
  let mut total = 0
  for group in groups {
    let members = match group {
      @lib.SingleRecType(subtype) => [subtype]
      @lib.GroupRecType(members) => members
    }
    starts.push(total)
    counts.push(members.length())
    total += members.length()
    for subtype in members {
      if subtype.metadata().is_shared() ||
        subtype.describes_type() is Some(_) ||
        subtype.descriptor_type() is Some(_) {
        return mod_
      }
      match subtype.get_comptype() {
        @lib.FuncCompType(_, _)
        | @lib.StructCompType(_)
        | @lib.ArrayCompType(_) => ()
        _ => return mod_
      }
    }
  }
  if total == 0 || !pass_type_cleanup_reference_surfaces_supported(mod_) {
    return mod_
  }
  let type_to_group = Array::make(total, -1)
  for group_idx = 0; group_idx < groups.length(); group_idx = group_idx + 1 {
    for offset = 0; offset < counts[group_idx]; offset = offset + 1 {
      type_to_group[starts[group_idx] + offset] = group_idx
    }
  }
  let refs : DfeTypeRefs = { live: Array::make(total, false), pending: [], }
  match root_scans {
    Some(count) => count[0] += 1
    None => ()
  }
  dfe_type_refs_module_roots(mod_.with_type_sec(@lib.TypeSec::new([])), refs)
  let live : Array[Bool] = Array::make(groups.length(), false)
  let pending_groups : Array[Int] = []
  let mut type_cursor = 0
  while type_cursor < refs.pending.length() {
    let type_slot = refs.pending[type_cursor]
    type_cursor += 1
    let group_idx = type_to_group[type_slot]
    if group_idx >= 0 && !live[group_idx] {
      live[group_idx] = true
      pending_groups.push(group_idx)
    }
  }
  let mut group_cursor = 0
  while group_cursor < pending_groups.length() {
    let owner = pending_groups[group_cursor]
    group_cursor += 1
    dfe_type_refs_rec_type(groups[owner], refs)
    while type_cursor < refs.pending.length() {
      let type_slot = refs.pending[type_cursor]
      type_cursor += 1
      let dependency = type_to_group[type_slot]
      if dependency >= 0 && !live[dependency] {
        live[dependency] = true
        pending_groups.push(dependency)
      }
    }
  }
  let kept : Array[@lib.RecType] = []
  let remap : Map[UInt, UInt] = Map([])
  let mut next = 0
  for group_idx = 0; group_idx < groups.length(); group_idx = group_idx + 1 {
    if live[group_idx] {
      kept.push(groups[group_idx])
      for offset = 0; offset < counts[group_idx]; offset = offset + 1 {
        remap[(starts[group_idx] + offset).to_uint()] = (next + offset).to_uint()
      }
      next += counts[group_idx]
    }
  }
  if next == total {
    return mod_
  }
  let mut candidate = dfe_rewrite_module_type_idxs(
    mod_.with_type_sec(@lib.TypeSec::new(kept)),
    remap,
  )
  match mod_.name_sec {
    Some(names) => {
      let type_names = match names.type_names {
        Some(names) => Some(dfe_rewrite_name_map_filtered(names, remap, true))
        None => None
      }
      let field_names = match names.field_names {
        Some(@lib.IndirectNameMap(entries)) => {
          let rewritten : Array[@lib.IndirectNameAssoc] = []
          for @lib.IndirectNameAssoc(old, fields) in entries {
            if remap.get(old) is Some(next) {
              rewritten.push(@lib.IndirectNameAssoc::new(next, fields))
            }
          }
          Some(@lib.IndirectNameMap::new(rewritten))
        }
        None => None
      }
      candidate = candidate.with_name_sec(
        @lib.NameSec::new(
          module_name=names.module_name,
          func_names=names.func_names,
          local_names=names.local_names,
          label_names=names.label_names,
          type_names~,
          field_names~,
          table_names=names.table_names,
          memory_names=names.memory_names,
          global_names=names.global_names,
          elem_names=names.elem_names,
          data_names=names.data_names,
          tag_names=names.tag_names,
        ),
      )
    }
    None => if mod_.raw_name_sec_payload is Some(_) { return mod_ }
  }
  match (@binary.encode_module(mod_), @binary.encode_module(candidate)) {
    (Ok(before), Ok(after)) if after.length() < before.length() =>
      if @validate.validate_module(candidate) is Ok(_) {
        return candidate
      }
    _ => ()
  }
  mod_
}

///|
fn pass_type_cleanup_reference_surfaces_supported(mod_ : @lib.Module) -> Bool {
  let expr_supported = fn(expr : @lib.Expr) {
    precompute_type_cleanup_instrs_supported(expr.0)
  }
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(_, expr) = func
        if !expr_supported(expr) {
          return false
        }
      }
    None => ()
  }
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      for global in globals {
        let @lib.Global(_, expr) = global
        if !expr_supported(expr) {
          return false
        }
      }
    None => ()
  }
  match mod_.table_sec {
    Some(@lib.TableSec(tables)) =>
      for table in tables {
        let @lib.Table(_, expr) = table
        if expr is Some(expr) && !expr_supported(expr) {
          return false
        }
      }
    None => ()
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) =>
      for elem in elems {
        let @lib.Elem(mode, kind) = elem
        if mode is @lib.Active(_, offset) && !expr_supported(offset) {
          return false
        }
        match kind {
          @lib.FuncExprsElemKind(exprs) | @lib.TypedExprsElemKind(_, exprs) =>
            for expr in exprs {
              if !expr_supported(expr) {
                return false
              }
            }
          _ => ()
        }
      }
    None => ()
  }
  match mod_.data_sec {
    Some(@lib.DataSec(datas)) =>
      for data in datas {
        let @lib.Data(mode, _) = data
        if mode is @lib.Active(_, offset) && !expr_supported(offset) {
          return false
        }
      }
    None => ()
  }
  true
}
