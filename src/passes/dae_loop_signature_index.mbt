///|
fn dae_parameter_loop_admission(
  mod_ : @lib.Module,
  imported : Int,
  defined : Int,
  function_infos : Array[DaeFunctionInfo],
  type_visits? : Array[Int]? = None,
) -> Array[Bool] {
  let admitted = Array::make(defined, true)
  match mod_.type_sec {
    Some(_) => {
      let indices : Array[@lib.TypeIdx] = []
      let owners : Array[Int] = []
      for def_idx = 0; def_idx < defined; def_idx = def_idx + 1 {
        let abs = imported + def_idx
        if abs < 0 || abs >= function_infos.length() {
          admitted[def_idx] = false
          continue
        }
        for type_idx in function_infos[abs].loop_type_indices {
          indices.push(type_idx)
          owners.push(def_idx)
        }
      }
      let signatures = dae_snapshot_function_types(
        mod_,
        indices,
        visited_types=type_visits,
      )
      for slot = 0; slot < signatures.length(); slot = slot + 1 {
        match signatures[slot] {
          Some(@lib.FuncType(params, _)) if !params.is_empty() =>
            admitted[owners[slot]] = false
          _ => ()
        }
      }
    }
    None =>
      for def_idx = 0; def_idx < defined; def_idx = def_idx + 1 {
        if !function_infos[imported + def_idx].loop_type_indices.is_empty() {
          admitted[def_idx] = false
        }
      }
  }
  admitted
}
