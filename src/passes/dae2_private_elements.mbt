///|
priv struct Dae2PrivateGroup {
  signatures : Array[@lib.SubType]
  slots : Array[Int]
}

///|
fn Dae2PrivateGroup::new() -> Dae2PrivateGroup {
  { signatures: [], slots: [], }
}

///|
fn Dae2PrivateGroup::append(
  self : Dae2PrivateGroup,
  workspace : Dae2TypeWorkspace,
  new_indices : Array[@lib.TypeIdx],
) -> Bool {
  if self.signatures.is_empty() {
    return false
  }
  if self.signatures.length() == 1 {
    // Source admission requires final singletons. An open singleton keeps
    // this one changed private target distinct without a witness member.
    let base = workspace.flat_count
    let @lib.TypeSec(groups) = workspace.types
    groups.push(
      @lib.RecType::new(
        @lib.SubType::new(false, [], self.signatures[0].get_comptype()),
      ),
    )
    workspace.flat_count += 1
    new_indices[self.slots[0]] = @lib.TypeIdx::new(base.to_uint())
    return true
  }
  let base = workspace.flat_count
  let @lib.TypeSec(groups) = workspace.types
  groups.push(@lib.RecType::group(self.signatures))
  workspace.flat_count += self.signatures.length()
  for member = 0; member < self.slots.length(); member = member + 1 {
    new_indices[self.slots[member]] = @lib.TypeIdx::new(
      (base + member).to_uint(),
    )
  }
  true
}

///|
// Imported code can invoke a function reference received as an argument. The
// signature stays observable even if the reference travels through a local.
fn dae2_has_host_callable_parameter(context : @ir.HotModuleContext) -> Bool {
  for index = 0; index < context.func_imports.length(); index = index + 1 {
    if context.func_imports[index] is None {
      break
    }
    let @lib.FuncType(params, _) = context.func_types[index]
    for param in params {
      match param {
        @lib.RefTypeValType(ref_type) =>
          match ref_type.get_heap_type() {
            @lib.AbsHeapTypeHeapType(@lib.FuncAbsHeapType)
            | @lib.SharedAbsHeapTypeHeapType(@lib.FuncAbsHeapType) =>
              return true
            @lib.HeapType(@lib.RecIdx(_)) => return true
            @lib.HeapType(type_idx) =>
              match @ir.hot_module_resolve_subtype(context, type_idx) {
                Some(subtype) =>
                  if subtype.get_comptype() is @lib.FuncCompType(_, _) {
                    return true
                  }
                None => ()
              }
            @lib.DefTypeHeapType(def_type) =>
              match def_type.project() {
                Some(subtype) =>
                  if subtype.get_comptype() is @lib.FuncCompType(_, _) {
                    return true
                  }
                None => ()
              }
            _ => ()
          }
        _ => ()
      }
    }
  }
  false
}

///|
fn dae2_private_element_candidate(e : DaeFunctionExposure) -> Bool {
  (e.active_element || e.passive_element) &&
  !e.imported &&
  !e.exported &&
  !e.start &&
  !e.ref_func_body &&
  !e.ref_func_module &&
  !e.declarative_element
}

///|
fn dae2_private_element_scalar(value : @lib.ValType) -> Bool {
  value is @lib.NumTypeValType(_) || value is @lib.VecTypeValType
}

///|
fn dae2_private_element_subtype(subtype : @lib.SubType) -> Bool {
  let metadata = subtype.metadata()
  if metadata.shared ||
    metadata.describes is Some(_) ||
    metadata.descriptor is Some(_) {
    return false
  }
  match subtype {
    @lib.SubType(final_, supers, _, _) =>
      if !final_ || !supers.is_empty() {
        return false
      }
    _ => ()
  }
  match subtype.get_comptype() {
    @lib.FuncCompType(params, results) =>
      params.all(dae2_private_element_scalar) &&
      results.all(dae2_private_element_scalar)
    _ => false
  }
}

///|
// Admit flat scalar bodies only. In particular, indirect calls, reference
// reads/tests, GC, handlers, and indexed control keep the existing family path.
// Reuse the numeric inventory without creating a second opcode table.
fn dae2_private_element_body(body : Array[@lib.Instruction]) -> Bool {
  for instr in body {
    match instr {
      @lib.StringConst(_)
      | @lib.RefNull(_)
      | @lib.RefFunc(_)
      | @lib.RefIsNull
      | @lib.RefTest(_, _, _)
      | @lib.TableSet(_)
      | @lib.StructSet(_, _)
      | @lib.ArraySet(_) => return false
      @lib.Select(Some(values)) =>
        if !values.all(dae2_private_element_scalar) {
          return false
        }
      @lib.Nop
      | @lib.Drop
      | @lib.Unreachable
      | @lib.Return
      | @lib.Br(_)
      | @lib.BrIf(_)
      | @lib.BrTable(_, _)
      | @lib.LocalSet(_)
      | @lib.LocalTee(_)
      | @lib.Call(_)
      | @lib.ReturnCall(_) => ()
      _ =>
        if dae2_raw_pure_arity(instr) < 0 && dae2_raw_observer_arity(instr) < 0 {
          return false
        }
    }
  }
  true
}

///|
fn dae2_private_element_mask(
  mod_ : @lib.Module,
  context : @ir.HotModuleContext,
  exposure : Array[DaeFunctionExposure],
  closed_world : Bool,
) -> Array[Bool]? {
  if !closed_world || !exposure.any(dae2_private_element_candidate) {
    return None
  }
  let @lib.TypeSec(groups) = mod_.type_sec.unwrap()
  for group in groups {
    match group {
      @lib.SingleRecType(subtype) =>
        if !dae2_private_element_subtype(subtype) {
          return None
        }
      @lib.GroupRecType(_) => return None
    }
  }
  // Concrete table/global/local references can observe the old contract.
  for table_type in context.tables {
    if !dae2_is_abstract_funcref_table(table_type) {
      return None
    }
  }
  for global_type in context.globals {
    let @lib.GlobalType(value, _) = global_type
    if !dae2_private_element_scalar(value) {
      return None
    }
  }
  match mod_.table_sec {
    Some(@lib.TableSec(tables)) =>
      for table in tables {
        let @lib.Table(_, init) = table
        if init is Some(_) {
          return None
        }
      }
    None => ()
  }
  match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) =>
      for elem in elems {
        let @lib.Elem(mode, kind) = elem
        if !(kind is @lib.FuncsElemKind(_)) {
          return None
        }
        match mode {
          @lib.Active(_, @lib.Expr(offset)) =>
            if !dae2_private_element_body(offset) {
              return None
            }
          _ => ()
        }
      }
    None => ()
  }
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      for global in globals {
        let @lib.Global(_, @lib.Expr(init)) = global
        if !dae2_private_element_body(init) {
          return None
        }
      }
    None => ()
  }
  match mod_.data_sec {
    Some(@lib.DataSec(datas)) =>
      for data in datas {
        let @lib.Data(mode, _) = data
        match mode {
          @lib.Active(_, @lib.Expr(offset)) =>
            if !dae2_private_element_body(offset) {
              return None
            }
          _ => ()
        }
      }
    None => ()
  }
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(body)) = func
        for run in locals.runs() {
          if !dae2_private_element_scalar(run.val_type()) {
            return None
          }
        }
        if !dae2_private_element_body(body) {
          return None
        }
      }
    None => ()
  }
  // A unique singleton type owned by one function cannot split an equivalent
  // source identity. Count shared keys without cloning their operand arrays.
  let counts : @hashmap.HashMap[@lib.CompType, Int] = @hashmap.new()
  for subtype in context.subtypes {
    let key = subtype.get_comptype()
    counts.set(key, counts.get(key).unwrap_or(0) + 1)
  }
  for type_idx in context.func_type_idxs {
    let key = context.subtypes[dae2_type_slot(type_idx, 0)].get_comptype()
    counts.set(key, counts.get(key).unwrap_or(0) + 1)
  }
  let mask = Array::make(exposure.length(), false)
  let mut any = false
  for index = 0; index < exposure.length(); index = index + 1 {
    if dae2_private_element_candidate(exposure[index]) {
      let signature = context.subtypes[dae2_type_slot(
        context.func_type_idxs[index],
        0,
      )].get_comptype()
      if counts.get(signature) == Some(2) {
        mask[index] = true
        any = true
      }
    }
  }
  if any {
    Some(mask)
  } else {
    None
  }
}

///|
// Private group members are numeric and index-free. Scan roots once, keep
// every member of a live group, then remap the module and its type name map.
// This removes obsolete source singletons without splitting group identities.
fn dae2_prune_private_element_source_types(mod_ : @lib.Module) -> @lib.Module {
  let @lib.TypeSec(groups) = mod_.type_sec.unwrap()
  for group in groups {
    match group {
      @lib.SingleRecType(subtype) =>
        if !dae2_private_element_subtype(subtype) {
          return mod_
        }
      @lib.GroupRecType(members) =>
        if !members.all(dae2_private_element_subtype) {
          return mod_
        }
    }
  }
  let refs : DfeTypeRefs = {
    live: Array::make(
      dae_type_sec_flattened_length(mod_.type_sec.unwrap()),
      false,
    ),
    pending: [],
  }
  dfe_type_refs_module_roots(mod_, refs)
  let kept : Array[@lib.RecType] = []
  let remap : Map[UInt, UInt] = Map([])
  let mut source = 0
  let mut destination = 0
  for group in groups {
    let count = match group {
      @lib.SingleRecType(_) => 1
      @lib.GroupRecType(members) => members.length()
    }
    let mut live = false
    for offset = 0; offset < count; offset = offset + 1 {
      live = live || refs.live[source + offset]
    }
    if live {
      kept.push(group)
      for offset = 0; offset < count; offset = offset + 1 {
        remap[(source + offset).to_uint()] = (destination + offset).to_uint()
      }
      destination += count
    }
    source += count
  }
  if source == destination {
    return mod_
  }
  let rewritten = dfe_rewrite_module_type_idxs(
    mod_.with_type_sec(@lib.TypeSec::new(kept)),
    remap,
  )
  match rewritten.name_sec {
    Some(names) =>
      rewritten.with_name_sec(dfe_rewrite_type_name_sec(names, remap))
    None => rewritten
  }
}
