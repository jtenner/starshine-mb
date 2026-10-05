///|
fn dae2_prepare_legacy_handlers_reference(
  mod_ : @lib.Module,
) -> Result[@lib.Module, String] {
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return Ok(mod_)
  }
  let env = @validate.Env::new().with_module(mod_)
  let types : HotPipelineLowerState = {
    next_type_sec: mod_.type_sec,
    type_sec_changed: false,
  }
  let bodies : Array[@lib.Func] = []
  let imported = dae_imported_func_count(mod_)
  let mut changed = false
  for index = 0; index < funcs.length(); index = index + 1 {
    let @lib.Func(locals, @lib.Expr(body)) = funcs[index]
    let params = match
      env.get_functype_by_funcidx(
        @lib.FuncIdx::new((index + imported).reinterpret_as_uint()),
      ) {
      Some(@lib.FuncType(params, _)) => params.length()
      None => return Err("dae2: missing legacy function type")
    }
    let local_types = locals.iter().to_array()
    let state : Dae2LegacyState = {
      env,
      types,
      locals: local_types,
      params,
      needs_exception_identity: dae2_legacy_has_rethrow(body),
      changed: false,
    }
    let body = match
      dae2_legacy_body(state, body, Dae2LegacyLabels::root(), []) {
      Ok(body) => body
      Err(err) => return Err(err)
    }
    changed = changed || state.changed
    bodies.push(
      @lib.Func::new(@lib.Locals::from_types(local_types), @lib.Expr::new(body)),
    )
  }
  if !changed {
    return Ok(mod_)
  }
  let next = mod_.with_code_sec(@lib.CodeSec::new(bodies))
  let next = match types.next_type_sec {
    Some(types) => next.with_type_sec(types)
    None => next
  }
  match @validate.validate_module(next) {
    Ok(_) => Ok(next)
    Err(err) => Err("dae2: invalid legacy handler adaptation: \{err}")
  }
}

///|
fn dae2_fold_known_local_throws_reference(mod_ : @lib.Module) -> @lib.Module {
  let bodies = match mod_.code_sec {
    Some(@lib.CodeSec(bodies)) => bodies
    None => return mod_
  }
  let env = @validate.Env::new().with_module(mod_)
  let imported_tags = @ir.hot_module_context_from_module(mod_).imported_tag_count
  mod_.with_code_sec(
    @lib.CodeSec::new(
      bodies.map(fn(func) {
        let @lib.Func(locals, @lib.Expr(body)) = func
        let (body, changed) = dae2_fold_known_local_throws_body(
          body, env, imported_tags,
        )
        let body = if changed && !dae2_body_has_exception_or_continuation(body) {
          // Remove unused void scaffolding only after dispatch folding has
          // eliminated exception scopes. Preserve every result block type.
          run_hot_pipeline_raw_vacuum_flatten_unbranched_result_blocks(
            body,
            true,
            false,
            flatten_results=false,
          ).0
        } else {
          body
        }
        @lib.Func::new(locals, @lib.Expr::new(body))
      }),
    ),
  )
}
