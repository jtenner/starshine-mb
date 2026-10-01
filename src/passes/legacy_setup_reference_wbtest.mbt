///|
fn dae2_legacy_setup_reference(
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
    if (dae2_handler_admission(body) & 2) == 0 {
      bodies.push(dae2_legacy_unchanged_func(funcs[index]))
      continue
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
    let body = match dae2_legacy_body(state, body, [0], []) {
      Ok(body) => body
      Err(err) => return Err(err)
    }
    changed = changed || state.changed
    bodies.push(
      if state.changed {
        @lib.Func::new(
          @lib.Locals::from_types(local_types),
          @lib.Expr::new(body),
        )
      } else {
        dae2_legacy_unchanged_func(funcs[index])
      },
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
