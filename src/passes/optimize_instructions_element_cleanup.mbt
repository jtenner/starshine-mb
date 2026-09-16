///|
fn oi_collect_declared_ref_funcs(
  body : Array[@lib.Instruction],
  declared : Map[UInt, Bool],
) -> Unit {
  for instr in body {
    if instr is @lib.RefFunc(@lib.FuncIdx(index)) {
      declared[index] = true
    }
    ignore(
      pass_lower_map_children(instr, fn(child) {
        oi_collect_declared_ref_funcs(child, declared)
        child
      }),
    )
  }
}

///|
fn oi_collect_elem_declarations(
  kind : @lib.ElemKind,
  declared : Map[UInt, Bool],
) -> Unit {
  match kind {
    @lib.FuncsElemKind(funcs) =>
      for func in funcs {
        let @lib.FuncIdx(index) = func
        declared[index] = true
      }
    @lib.FuncExprsElemKind(exprs) | @lib.TypedExprsElemKind(_, exprs) =>
      for expr in exprs {
        let @lib.Expr(body) = expr
        oi_collect_declared_ref_funcs(body, declared)
      }
  }
}

///|
fn oi_cleanup_declarative_elements(mod_ : @lib.Module) -> @lib.Module {
  if mod_.name_sec is None && mod_.raw_name_sec_payload is Some(_) {
    return mod_
  }
  let elems = match mod_.elem_sec {
    Some(@lib.ElemSec(elems)) => elems
    None => return mod_
  }
  // Reindexing runtime segment operands needs a separate complete remapper.
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(_, @lib.Expr(body)) = func
        if o4z_canonicalize_final_size_instrs_use_elem_indices(body) {
          return mod_
        }
      }
    None => ()
  }
  // A raw declaration only enables ref.func validation. With no ref.func
  // sites and no active/passive/initializer segments, none are required.
  let declarations_unused = elems.all(fn(elem) {
      elem is @lib.Elem(@lib.Declarative, @lib.FuncsElemKind(_))
    }) &&
    !o4z_canonicalize_final_size_module_has_ref_func(mod_)
  let declared : Map[UInt, Bool] = Map([])
  // Match validation's declaration sources: body ref.func and start do not
  // declare a function. Seed coverage only with sites that will be retained.
  match mod_.export_sec {
    Some(@lib.ExportSec(exports)) =>
      for export_ in exports {
        if export_ is @lib.Export(_, @lib.FuncExternIdx(@lib.FuncIdx(index))) {
          declared[index] = true
        }
      }
    None => ()
  }
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      for global in globals {
        let @lib.Global(_, @lib.Expr(body)) = global
        oi_collect_declared_ref_funcs(body, declared)
      }
    None => ()
  }
  match mod_.table_sec {
    Some(@lib.TableSec(tables)) =>
      for table in tables {
        let @lib.Table(_, init) = table
        if init is Some(@lib.Expr(body)) {
          oi_collect_declared_ref_funcs(body, declared)
        }
      }
    None => ()
  }
  for elem in elems {
    match elem {
      @lib.Elem(@lib.Declarative, @lib.FuncsElemKind(_)) => ()
      @lib.Elem(_, kind) => oi_collect_elem_declarations(kind, declared)
    }
  }
  let kept : Array[@lib.Elem] = []
  let remap : Array[Int] = []
  for elem in elems {
    match elem {
      @lib.Elem(@lib.Declarative, @lib.FuncsElemKind(funcs)) => {
        if declarations_unused ||
          funcs.all(fn(func) {
            let @lib.FuncIdx(index) = func
            declared.contains(index)
          }) {
          remap.push(-1)
          continue
        }
        // Retain the first necessary declaration before considering later
        // duplicates, so duplicates cannot justify deleting each other.
        oi_collect_elem_declarations(@lib.ElemKind::funcs(funcs), declared)
      }
      _ => ()
    }
    remap.push(kept.length())
    kept.push(elem)
  }
  if kept.length() == elems.length() {
    return mod_
  }
  let candidate = if kept.is_empty() {
    o4z_canonicalize_final_size_without_elem_sec(mod_)
  } else {
    mod_.with_elem_sec(@lib.ElemSec::new(kept))
  }
  match candidate.name_sec {
    Some(names) => {
      let elem_names = match names.elem_names {
        Some(names) => rl_rewrite_name_map(names, remap)
        None => None
      }
      candidate.with_name_sec(
        @lib.NameSec::new(
          module_name=names.module_name,
          func_names=names.func_names,
          local_names=names.local_names,
          label_names=names.label_names,
          type_names=names.type_names,
          table_names=names.table_names,
          memory_names=names.memory_names,
          global_names=names.global_names,
          elem_names~,
          data_names=names.data_names,
          field_names=names.field_names,
          tag_names=names.tag_names,
        ),
      )
    }
    None => candidate
  }
}
