///|
fn remove_empty_function_exports_run_module_pass(
  mod_ : @lib.Module,
) -> @lib.Module {
  let @lib.ExportSec(exports) = match mod_.export_sec {
    Some(section) => section
    None => return mod_
  }
  let defined_start = run_hot_pipeline_imported_func_count(mod_)
  let funcs = match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs
    None => return mod_
  }
  let retained : Array[@lib.Export] = []
  for export_ in exports {
    let remove = match export_ {
      @lib.Export(_, @lib.FuncExternIdx(@lib.FuncIdx(abs_idx))) => {
        let local_idx = abs_idx.to_int() - defined_start
        if local_idx < 0 || local_idx >= funcs.length() {
          false
        } else {
          match funcs[local_idx] {
            @lib.Func(_, @lib.Expr([])) | @lib.Func(_, @lib.Expr([@lib.Nop])) =>
              true
            @lib.Func(_, @lib.Expr([@lib.Block(_, @lib.Expr([]))])) => true
            _ => false
          }
        }
      }
      _ => false
    }
    if !remove {
      retained.push(export_)
    }
  }
  if retained.length() == exports.length() {
    mod_
  } else {
    mod_.with_export_sec(@lib.ExportSec::new(retained))
  }
}
