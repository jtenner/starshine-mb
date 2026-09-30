///|
// Frozen V24b section-only lookup, including full type-section materialization.
fn signature_lookup_reference_types(
  type_sec : @lib.TypeSec?,
) -> Array[@lib.SubType] {
  let out : Array[@lib.SubType] = []
  match type_sec {
    Some(@lib.TypeSec(rec_types)) =>
      for rec_type in rec_types {
        match rec_type {
          @lib.SingleRecType(subtype) => out.push(subtype)
          @lib.GroupRecType(group) =>
            for subtype in group {
              out.push(subtype)
            }
        }
      }
    None => ()
  }
  out
}

///|
fn signature_lookup_reference_params(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
) -> Array[@lib.ValType]? {
  let imported_func_count = run_hot_pipeline_imported_func_count(mod_)
  let @lib.FuncIdx(raw) = func_idx
  let code_idx = raw.reinterpret_as_int() - imported_func_count
  if code_idx < 0 {
    return None
  }
  let type_idx = match mod_.func_sec {
    Some(@lib.FuncSec(type_idxs)) =>
      match type_idxs.get(code_idx) {
        Some(idx) => idx
        None => return None
      }
    None => return None
  }
  let type_pos = match type_idx {
    @lib.TypeIdx(type_raw) => type_raw.reinterpret_as_int()
    @lib.RecIdx(_) => return None
  }
  match signature_lookup_reference_types(mod_.type_sec).get(type_pos) {
    Some(subtype) =>
      match subtype.get_comptype() {
        @lib.FuncCompType(params, _) => Some(params)
        _ => None
      }
    None => None
  }
}
