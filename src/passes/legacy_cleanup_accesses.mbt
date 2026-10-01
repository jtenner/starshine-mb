///|
fn sl_legacy_try_has_local_access(
  body : Array[@lib.Instruction],
  catches : Array[@lib.LegacyCatch],
  local_id : Int,
  reads : Bool,
) -> Bool {
  let body_access = if reads {
    run_hot_pipeline_raw_instrs_have_later_local_read(body, 0, local_id)
  } else {
    run_hot_pipeline_raw_instrs_have_later_local_write(body, 0, local_id)
  }
  if body_access {
    return true
  }
  for catch_ in catches {
    let @lib.Expr(body) = match catch_ {
      @lib.LegacyCatch(_, expr) | @lib.LegacyCatchAll(expr) => expr
    }
    let handler_access = if reads {
      run_hot_pipeline_raw_instrs_have_later_local_read(body, 0, local_id)
    } else {
      run_hot_pipeline_raw_instrs_have_later_local_write(body, 0, local_id)
    }
    if handler_access {
      return true
    }
  }
  false
}
