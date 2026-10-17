///|
// Frozen cleanup before per-function admission.
fn dae2_cleanup_sparse_reference(mod_ : @lib.Module) -> @lib.Module {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  if funcs.is_empty() {
    return mod_
  }
  let params = rl_defined_func_param_cache(mod_)
  let module_ctx = @ir.hot_module_context_from_module(mod_)
  let mut may_change = false
  for index = 0; index < funcs.length(); index = index + 1 {
    if dae2_cleanup_func_may_change(funcs[index], params[index], module_ctx) {
      may_change = true
      break
    }
  }
  if !may_change {
    return mod_
  }
  let mut module_env : @validate.Env? = None
  let stack_effects = Some(fn(instr) {
    dae2_capture_stack_effect(instr, mod_, module_ctx)
  })
  let remaps : Array[Array[Int32]?] = []
  let changed_labels : Array[Bool] = []
  let bodies : Array[@lib.Func] = []
  for index = 0; index < funcs.length(); index = index + 1 {
    let @lib.Func(locals, @lib.Expr(instrs)) = funcs[index]
    let (instrs, forwarding_changed, scalar) = dae2_cleanup_forwarding(
      instrs, module_ctx,
    )
    let input = @lib.Func::new(locals, @lib.Expr::new(instrs))
    let (input, labels_changed) = if scalar {
      let env = match module_env {
        Some(env) => env
        None => {
          let env = @validate.Env::new().with_module(mod_)
          module_env = Some(env)
          env
        }
      }
      let (input, blocks_changed) = pass_lower_cleanup_branchless_blocks(
        input,
        mod_,
        module_env=Some(env),
      )
      (input, forwarding_changed || blocks_changed)
    } else {
      (input, forwarding_changed)
    }
    changed_labels.push(labels_changed)
    let (body, mapping) = pass_lower_compact_captures_with_map(
      input,
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      params[index],
      stack_effects~,
      propagate_parameter_aliases=true,
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
