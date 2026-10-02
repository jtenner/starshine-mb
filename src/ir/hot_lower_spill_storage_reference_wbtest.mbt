///|
// Frozen db1412a75 private lowering worker for exact bounded controls.
fn hot_lower_spill_storage_original_instr(
  func : HotFunc,
  instr : Instruction,
) -> Instruction {
  match instr {
    Block(bt, Expr(body)) =>
      Instruction::block(
        bt,
        Expr::new(hot_lower_spill_storage_original_body(func, body)),
      )
    Loop(bt, Expr(body)) =>
      Instruction::loop_(
        bt,
        Expr::new(hot_lower_spill_storage_original_body(func, body)),
      )
    If(bt, then_, else_) =>
      Instruction::if_(
        bt,
        hot_lower_spill_storage_original_body(func, then_),
        match else_ {
          Some(else_body) =>
            Some(hot_lower_spill_storage_original_body(func, else_body))
          None => None
        },
      )
    TryTable(bt, catches, Expr(body)) =>
      Instruction::try_table(
        bt,
        catches,
        Expr::new(hot_lower_spill_storage_original_body(func, body)),
      )
    _ => instr
  }
}

///|
fn hot_lower_spill_storage_original_body(
  func : HotFunc,
  body : Array[Instruction],
) -> Array[Instruction] {
  let nested : Array[Instruction] = []
  for instr in body {
    nested.push(hot_lower_spill_storage_original_instr(func, instr))
  }
  let rewritten : Array[Instruction] = []
  let mut i = 0
  while i < nested.length() {
    if i + 4 < nested.length() {
      let lhs = nested[i]
      let rhs = nested[i + 1]
      let op_instr = nested[i + 2]
      let set_instr = nested[i + 3]
      let get_instr = nested[i + 4]
      let rhs_is_const = match rhs {
        I32Const(_)
        | I64Const(_)
        | F32Const(_)
        | F64Const(_)
        | RefNull(_)
        | StringConst(_) => true
        _ => false
      }
      if rhs_is_const && !hot_lower_impl_has_control_transfer(op_instr) {
        match lhs {
          LocalGet(source_local) =>
            match set_instr {
              LocalSet(target_local) if target_local != source_local &&
                !hot_lower_impl_body_has_later_local_get(
                  nested,
                  i + 5,
                  target_local,
                ) =>
                match get_instr {
                  LocalGet(found_local) if found_local == target_local =>
                    match (source_local, target_local) {
                      (LocalIdx(raw_source), LocalIdx(raw_target)) => {
                        let source_local_id = raw_source.reinterpret_as_int()
                        let target_local_id = raw_target.reinterpret_as_int()
                        match
                          (
                            hot_local_type(func, source_local_id),
                            hot_local_type(func, target_local_id),
                          ) {
                          (Some(source_ty), Some(target_ty)) if source_ty ==
                            target_ty => {
                            rewritten.push(lhs)
                            rewritten.push(set_instr)
                            rewritten.push(get_instr)
                            rewritten.push(rhs)
                            rewritten.push(op_instr)
                            i = i + 5
                            continue
                          }
                          _ => ()
                        }
                      }
                    }
                  _ => ()
                }
              _ => ()
            }
          _ => ()
        }
      }
    }
    rewritten.push(nested[i])
    i = i + 1
  }
  rewritten
}
