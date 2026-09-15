///|
// A bounded optional encoding cleanup. Whole recursion groups remain indivisible;
// only global indices are renamed, preserving relative recursive identities.
fn pass_cleanup_unused_type_groups(mod_ : @lib.Module) -> @lib.Module {
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
  // The existing reference scanner is probe-based. Bound that optional work
  // until a one-pass type-reference collector replaces it.
  if total == 0 ||
    total > 128 ||
    !pass_type_cleanup_reference_surfaces_supported(mod_) {
    return mod_
  }
  let mut nodes = 0
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(_, @lib.Expr(body)) = func
        nodes += pass_type_cleanup_instruction_count(body)
        if nodes > 4096 {
          return mod_
        }
      }
    None => ()
  }
  let probes : Array[Map[UInt, UInt]] = []
  let live : Array[Bool] = Array::make(groups.length(), false)
  let roots = mod_.with_type_sec(@lib.TypeSec::new([]))
  for group_idx = 0; group_idx < groups.length(); group_idx = group_idx + 1 {
    let probe : Map[UInt, UInt] = Map([])
    for offset = 0; offset < counts[group_idx]; offset = offset + 1 {
      probe[(starts[group_idx] + offset).to_uint()] = total.to_uint()
    }
    probes.push(probe)
    live[group_idx] = dfe_module_type_refs_use_remap(roots, probe)
  }
  let pending : Array[Int] = []
  for idx = 0; idx < groups.length(); idx = idx + 1 {
    if live[idx] {
      pending.push(idx)
    }
  }
  while pending.pop() is Some(owner) {
    for dependency = 0
        dependency < groups.length()
        dependency = dependency + 1 {
      if !live[dependency] &&
        dfe_rec_type_uses_remap(groups[owner], probes[dependency]) {
        live[dependency] = true
        pending.push(dependency)
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
fn pass_type_cleanup_instruction_count(body : Array[@lib.Instruction]) -> Int {
  let mut count = body.length()
  for instr in body {
    ignore(
      pass_lower_map_children(instr, fn(children) {
        count += pass_type_cleanup_instruction_count(children)
        children
      }),
    )
  }
  count
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
