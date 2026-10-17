///|
// Frozen try_table worker from HEAD before the initialization-fork experiment.
// It retains the eager entry-mask copy and every original validation step.
fn tc_try_table_owned_reference(
  st : TcState,
  bt : BlockType,
  catches : Array[Catch],
  body : Expr,
) -> TcResult {
  let (params, results) = match st.env.expand_blocktype(bt) { // assuming you made it a method
    Err(e) => return Err(e)
    Ok(x) => x
  }

  // consume params
  let st1 = match st.pop_types(params) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // extend context with innermost label = results
  let env2 = st1.env.with_label(results)
  let st_body0 = TcState::{
    env: env2,
    stack: tc_stack_from_types(params),
    reachable: st1.reachable,
    polymorphic: false,
    escape: NoTcEscape,
    reachable_escape_depths: [],
    initialized_locals: st1.initialized_locals.copy(),
  }

  // body must typecheck under extended env
  let st_body = match Typecheck::typecheck(body, st_body0) {
    Err(e) => return Err(e)
    Ok(s) => s
  }

  // Catch branch targets are resolved in the enclosing label space, not the
  // try_table's temporary body label.
  let st_catch_ctx = st1
  for c in catches {
    match typecheck_catch_clause(st_catch_ctx, c) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
  }

  match validate_end_stack(st_body, results) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }

  tc_state_finish_try_table(st, st1, st_body, results, catches)
}
