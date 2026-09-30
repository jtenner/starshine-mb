///|
// Frozen V45 compactor and parameter-alias cleanup; shared local counting.
fn compaction_admission_reference_compact(
  func : @lib.Func,
  original : @lib.Func,
  params : Array[@lib.ValType],
  stack_effects? : ((@lib.Instruction) -> (Int, Int)?)? = None,
  propagate_parameter_aliases? : Bool = false,
) -> (@lib.Func, Array[Int]) {
  let @lib.Func(original_locals, _) = original
  let @lib.Func(locals, @lib.Expr(body)) = func
  if locals.length() <= original_locals.length() {
    return (func, Array::makei(params.length() + locals.length(), fn(i) { i }))
  }
  let count = params.length() + locals.length()
  let start = params.length() + original_locals.length()
  let gets = Array::make(count, 0)
  let writes = Array::make(count, 0)
  pass_lower_count_locals(body, gets, writes)
  // Keep the existing leaf plan first: an earlier effect-spanning capture can
  // otherwise block several smaller overlapping captures. The second pass
  // only deletes additional pairs from that already valid stack plan.
  let body = pass_lower_remove_balanced_captures(body, start, gets, writes)
  let body = match stack_effects {
    Some(_) => {
      let mut remaining = false
      for local in start..<count {
        if gets[local] == 1 && writes[local] == 1 {
          remaining = true
          break
        }
      }
      if remaining {
        pass_lower_remove_balanced_captures(
          body,
          start,
          gets,
          writes,
          stack_effects~,
        )
      } else {
        body
      }
    }
    None => body
  }
  // Preserve the complete legacy capture plan before alias propagation.
  // Moving even a pure parameter read can otherwise obstruct a smaller stack
  // plan chosen for an overlapping computed value.
  let (body, unread_aliases) = if propagate_parameter_aliases {
    local_alias_reference_cleanup(body, start, params.length(), gets, writes)
  } else {
    (body, None)
  }
  let indices = Array::makei(count, fn(i) { i })
  let retained : Array[@lib.ValType] = []
  for i = 0; i < locals.length(); i = i + 1 {
    let index = params.length() + i
    if index < start || gets[index] > 0 || writes[index] > 0 {
      indices[index] = params.length() + retained.length()
      retained.push(locals.get(i))
    } else {
      indices[index] = -1
    }
  }
  (
    @lib.Func::new(
      @lib.Locals::from_types(retained),
      @lib.Expr::new(
        match unread_aliases {
          Some(aliases) => local_alias_reference_remap(body, indices, aliases)
          None => pass_lower_remap_locals(body, indices)
        },
      ),
    ),
    indices,
  )
}
