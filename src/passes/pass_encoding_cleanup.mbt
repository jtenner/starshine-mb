///|
fn pass_encoding_cleanup_has_removable_nop(
  body : Array[@lib.Instruction],
) -> Bool {
  for instr in body {
    match instr {
      @lib.Nop => return true
      @lib.Block(_, @lib.Expr(child))
      | @lib.Loop(_, @lib.Expr(child))
      | @lib.TryTable(_, _, @lib.Expr(child)) =>
        if pass_encoding_cleanup_has_removable_nop(child) {
          return true
        }
      @lib.If(_, yes, no) => {
        if pass_encoding_cleanup_has_removable_nop(yes) {
          return true
        }
        match no {
          Some(child) =>
            if pass_encoding_cleanup_has_removable_nop(child) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
// Run after writeback repair, while restored functions still use their original
// type and local indices. Reuse the label-name-aware control cleanup and the
// validated byte-saving type and local remappers.
fn pass_cleanup_control_and_type_encoding(
  mod_ : @lib.Module,
  touched? : Array[Bool]? = None,
  nop_rewrite_attempts? : Array[Int]? = None,
  flatten_attempts? : Array[Int]? = None,
  perf? : HotPerfSession? = None,
) -> @lib.Module {
  if pass_module_has_offset_sensitive_metadata(mod_) {
    return mod_
  }
  let nop_start = perf_start_timer_opt(
    perf, "detail:simplify-locals:encoding-nops",
  )
  let without_nops = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let mut changed = false
      let rewritten = funcs.mapi(fn(index, func) {
        if touched is Some(selected) &&
          (index >= selected.length() || !selected[index]) {
          return func
        }
        let @lib.Func(locals, @lib.Expr(body)) = func
        if !pass_encoding_cleanup_has_removable_nop(body) {
          return func
        }
        match nop_rewrite_attempts {
          Some(attempts) => attempts[0] += 1
          None => ()
        }
        let (body, body_changed) = dae_remove_nops_instrs(body)
        if !body_changed {
          return func
        }
        changed = true
        @lib.Func::new(locals, @lib.Expr::new(body))
      })
      if changed {
        mod_.with_code_sec(@lib.CodeSec::new(rewritten))
      } else {
        mod_
      }
    }
    None => mod_
  }
  perf_stop_timer_opt(perf, "detail:simplify-locals:encoding-nops", nop_start)
  let control_start = perf_start_timer_opt(
    perf, "detail:simplify-locals:encoding-control",
  )
  let cleaned = oi_cleanup_control(without_nops, touched~, flatten_attempts~)
  perf_stop_timer_opt(
    perf, "detail:simplify-locals:encoding-control", control_start,
  )
  let type_start = perf_start_timer_opt(
    perf, "detail:simplify-locals:encoding-type",
  )
  let result = if pass_encoding_cleanup_may_remap_types(cleaned, touched) {
    dfe_cleanup_simple_type_encoding(cleaned, perf~)
  } else {
    cleaned
  }
  perf_stop_timer_opt(perf, "detail:simplify-locals:encoding-type", type_start)
  result
}

///|
// Inlining restores original bodies outside the selected functions. Their
// embedded type indices must keep the original module-wide meaning.
fn pass_encoding_cleanup_may_remap_types(
  mod_ : @lib.Module,
  touched : Array[Bool]?,
) -> Bool {
  match touched {
    None => true
    Some(selected) =>
      match mod_.code_sec {
        Some(@lib.CodeSec(funcs)) => {
          for index = 0; index < funcs.length(); index = index + 1 {
            if index >= selected.length() || !selected[index] {
              return false
            }
          }
          true
        }
        None => true
      }
  }
}
