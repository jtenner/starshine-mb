///|
// Lowering can retain a tuple forwarding wrapper after SimplifyLocals. A
// zero-parameter block containing only local reads cannot branch, trap or
// consume the enclosing stack. Removing that wrapper exposes capture pairs.
fn dae2_balanced_capture_reference_tuple_forwarding(
  instrs : Array[@lib.Instruction],
  module_ctx : @ir.HotModuleContext,
) -> (Array[@lib.Instruction], Bool) {
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  for instr in instrs {
    match instr {
      @lib.Block(@lib.TypeIdxBlockType(index), @lib.Expr(body)) if body.all(fn(
          instr,
        ) {
          instr is @lib.LocalGet(_)
        }) =>
        match @ir.hot_module_resolve_type_func_type(module_ctx, index) {
          Some(@lib.FuncType([], results)) if results.length() > 1 &&
            results.length() == body.length() => {
            out.append(body)
            changed = true
            continue
          }
          _ => ()
        }
      _ => ()
    }
    out.push(
      pass_lower_map_children(instr, fn(body) {
        let (body, nested_changed) = dae2_balanced_capture_reference_tuple_forwarding(
          body, module_ctx,
        )
        changed = changed || nested_changed
        body
      }),
    )
  }
  (out, changed)
}

///|
// Frozen V30 final capture cleanup for focused before/after controls.
fn dae2_balanced_capture_reference_cleanup(mod_ : @lib.Module) -> @lib.Module {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  if funcs.is_empty() {
    return mod_
  }
  let params = rl_defined_func_param_cache(mod_)
  let module_ctx = @ir.hot_module_context_from_module(mod_)
  let remaps : Array[Array[Int32]?] = []
  let changed_labels : Array[Bool] = []
  let bodies : Array[@lib.Func] = []
  for index = 0; index < funcs.length(); index = index + 1 {
    let @lib.Func(locals, @lib.Expr(instrs)) = funcs[index]
    let (instrs, labels_changed) = dae2_balanced_capture_reference_tuple_forwarding(
      instrs, module_ctx,
    )
    changed_labels.push(labels_changed)
    let input = @lib.Func::new(locals, @lib.Expr::new(instrs))
    let (body, mapping) = pass_lower_compact_captures_with_map(
      input,
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      params[index],
    )
    bodies.push(body)
    remaps.push(Some(mapping))
  }
  let next = mod_.with_code_sec(@lib.CodeSec::new(bodies))
  let imported = rl_imported_func_count(mod_)
  match rl_rewrite_name_sec(mod_.name_sec, imported, remaps) {
    Some(names) => {
      // Removing a control label changes the ordinal of later labels. Keep
      // metadata for unchanged functions; changed functions have no label map.
      let label_names = match names.label_names {
        Some(@lib.IndirectNameMap(entries)) => {
          let retained = entries.filter(fn(entry) {
            let @lib.IndirectNameAssoc(index, _) = entry
            let defined = index.to_int() - imported
            defined < 0 ||
            defined >= changed_labels.length() ||
            !changed_labels[defined]
          })
          if retained.is_empty() {
            None
          } else {
            Some(@lib.IndirectNameMap::new(retained))
          }
        }
        None => None
      }
      next.with_name_sec(
        @lib.NameSec::new(
          module_name=names.module_name,
          func_names=names.func_names,
          local_names=names.local_names,
          label_names~,
          type_names=names.type_names,
          table_names=names.table_names,
          memory_names=names.memory_names,
          global_names=names.global_names,
          elem_names=names.elem_names,
          data_names=names.data_names,
          field_names=names.field_names,
          tag_names=names.tag_names,
        ),
      )
    }
    None => next.without_name_sec()
  }
}
