///|
// A former mixed-capture fallback may keep its natural stack form when its
// complete local space fits one-byte indices. Group exact body-local types:
// no instruction grows, and each distinct type needs only one declaration.
fn dae2_raw_group_small_body_locals(
  func : @lib.Func,
  params : Int32,
) -> (@lib.Func, Array[Int32]) {
  let @lib.Func(locals, body) = func
  let count = locals.length()
  let total = params + count
  if params < 0 || total > 128 {
    abort("raw local grouping requires one-byte local indices")
  }
  let types = rl_flatten_locals(locals, count)
  let indices = Array::make(total, -1)
  for local in 0..<params {
    indices[local] = local
  }
  let grouped : Array[@lib.ValType] = []
  let mut changed = false
  for first in 0..<count {
    if indices[params + first] >= 0 {
      continue
    }
    for local in first..<count {
      if types[local] == types[first] {
        let next = params + grouped.length()
        indices[params + local] = next
        changed = changed || next != params + local
        grouped.push(types[local])
      }
    }
  }
  if !changed {
    return (func, indices)
  }
  (
    @lib.Func::new(
      @lib.Locals::from_types(grouped),
      rl_rewrite_expr(body, indices),
    ),
    indices,
  )
}
