///|
fn numeric_group_reference_func(
  func : @lib.Func,
  params : Array[@lib.ValType],
) -> (@lib.Func, Array[Int]?) {
  let @lib.Func(locals, @lib.Expr(instrs)) = func
  if locals.length() <= 1 {
    return (func, None)
  }
  for param in params {
    if !run_hot_pipeline_raw_numeric_local_type(param) {
      return (func, None)
    }
  }
  for local_idx = 0; local_idx < locals.length(); local_idx = local_idx + 1 {
    if !run_hot_pipeline_raw_numeric_local_type(locals.get(local_idx)) {
      return (func, None)
    }
  }
  let buckets : Array[@lib.ValType] = []
  for local_idx = 0; local_idx < locals.length(); local_idx = local_idx + 1 {
    let ty = locals.get(local_idx)
    if run_hot_pipeline_raw_local_type_bucket_index(buckets, ty) < 0 {
      buckets.push(ty)
    }
  }
  let param_count = params.length()
  let total_local_count = param_count + locals.length()
  let local_remap : Array[Int] = []
  for local_id = 0; local_id < total_local_count; local_id = local_id + 1 {
    local_remap.push(local_id)
  }
  let grouped_local_types : Array[@lib.ValType] = []
  let mut changed = false
  for bucket_idx = 0; bucket_idx < buckets.length(); bucket_idx = bucket_idx + 1 {
    let bucket_ty = buckets[bucket_idx]
    for local_idx = 0; local_idx < locals.length(); local_idx = local_idx + 1 {
      if locals.get(local_idx) == bucket_ty {
        let old_local_id = param_count + local_idx
        let next_local_id = param_count + grouped_local_types.length()
        if old_local_id != next_local_id {
          changed = true
          local_remap[old_local_id] = next_local_id
        }
        grouped_local_types.push(bucket_ty)
      }
    }
  }
  let grouped_locals = @lib.Locals::from_types(grouped_local_types)
  if !changed && grouped_locals == locals {
    return (func, None)
  }
  (
    @lib.Func::new(
      grouped_locals,
      @lib.Expr::new(
        run_hot_pipeline_raw_compact_rewrite_local_refs(instrs, local_remap),
      ),
    ),
    Some(local_remap),
  )
}
