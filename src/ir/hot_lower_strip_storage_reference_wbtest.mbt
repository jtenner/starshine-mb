///|
// Frozen45df918c9 helper, exact predicates/options and output construction.
fn hot_lower_strip_storage_reference(
  body : Array[Instruction],
  options : HotLowerOptions,
) -> Array[Instruction] {
  let stripped : Array[Instruction] = []
  let mut i = 0
  while i < body.length() {
    match body[i] {
      Unreachable => {
        stripped.push(body[i])
        i = i + 1
        while i < body.length() {
          match body[i] {
            Nop | Drop | Block(_, Expr([])) => i = i + 1
            _ => break
          }
        }
        continue
      }
      Nop => {
        if (options.preserve_nontrailing_nops && i + 1 < body.length()) ||
          (options.preserve_trailing_nops && i + 1 == body.length()) {
          stripped.push(body[i])
        }
        i = i + 1
        continue
      }
      LocalTee(local_) if i + 1 < body.length() =>
        match body[i + 1] {
          Drop => {
            if options.preserve_dead_local_tee_drops {
              stripped.push(body[i])
              i = i + 1
              continue
            }
            if hot_lower_impl_body_has_later_local_get(body, i + 2, local_) {
              stripped.push(body[i])
              i = i + 1
              continue
            }
            stripped.push(Instruction::local_set(local_))
            i = i + 2
            continue
          }
          _ => ()
        }
      _ => ()
    }
    stripped.push(body[i])
    i = i + 1
  }
  stripped
}
