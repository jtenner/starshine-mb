///|
pub fn propagate_globals_globally_summary() -> String {
  "Propagate known literal globals through later global initializers and active segment offsets."
}

///|
fn pgg_imported_global_count(mod_ : @lib.Module) -> Int {
  let mut count = 0
  match mod_.import_sec {
    Some(@lib.ImportSec(imports)) =>
      for import_ in imports {
        match import_ {
          @lib.Import(_, _, @lib.GlobalExternType(_)) => count += 1
          _ => ()
        }
      }
    None => ()
  }
  count
}

///|
fn pgg_rewrite_globals(
  global_sec : @lib.GlobalSec?,
  imported_globals : Int,
) -> (@lib.GlobalSec?, Array[@lib.Instruction?], Bool) {
  let defined_globals = match global_sec {
    Some(@lib.GlobalSec(globals)) => globals.length()
    None => 0
  }
  let total_globals = imported_globals + defined_globals
  let known = sgo_empty_const_array(total_globals)
  let aliases = sgo_empty_global_idx_array(total_globals)
  let inlines = sgo_empty_expr_array(total_globals)
  match global_sec {
    Some(@lib.GlobalSec(globals)) => {
      let rewritten_globals : Array[@lib.Global] = []
      let mut changed = false
      for defined_idx = 0
          defined_idx < globals.length()
          defined_idx = defined_idx + 1 {
        let @lib.Global(global_type, init) = globals[defined_idx]
        let (rewritten_init, init_changed) = sgo_rewrite_global_init_expr(
          init, known, aliases, inlines,
        )
        changed = changed || init_changed
        known[imported_globals + defined_idx] = sgo_expr_single_const(
          rewritten_init,
        )
        rewritten_globals.push(@lib.Global::new(global_type, rewritten_init))
      }
      (Some(@lib.GlobalSec::new(rewritten_globals)), known, changed)
    }
    None => (None, known, false)
  }
}

///|
pub fn propagate_globals_globally_run_module_pass(
  mod_ : @lib.Module,
) -> @lib.Module {
  let imported_globals = pgg_imported_global_count(mod_)
  let (global_sec, known, global_changed) = pgg_rewrite_globals(
    mod_.global_sec,
    imported_globals,
  )
  let remove_sets = Array::make(known.length(), false)
  let (elem_sec, elem_changed) = sgo_rewrite_elem_sec(
    mod_.elem_sec,
    known,
    remove_sets,
  )
  let (data_sec, data_changed) = sgo_rewrite_data_sec(
    mod_.data_sec,
    known,
    remove_sets,
  )
  if !global_changed && !elem_changed && !data_changed {
    return mod_
  }
  sgo_build_module(
    mod_,
    global_sec,
    mod_.table_sec,
    elem_sec,
    data_sec,
    mod_.code_sec,
  )
}
