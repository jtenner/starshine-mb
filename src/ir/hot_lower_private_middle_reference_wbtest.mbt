///|
// Frozen private middle passes before lazy unchanged-container retention.

///|
fn lower_middle_reference_prune_dead_local_tees_in_instr(
  instr : Instruction,
  counts : Array[Int32],
  options : HotLowerOptions,
) -> Instruction? {
  match instr {
    Block(bt, Expr(body)) =>
      Some(
        Instruction::block(
          bt,
          Expr::new(
            lower_middle_reference_prune_dead_local_tees_in_body(
              body, counts, options,
            ),
          ),
        ),
      )
    Loop(bt, Expr(body)) =>
      Some(
        Instruction::loop_(
          bt,
          Expr::new(
            lower_middle_reference_prune_dead_local_tees_in_body(
              body, counts, options,
            ),
          ),
        ),
      )
    If(bt, then_, else_) =>
      Some(
        Instruction::if_(
          bt,
          lower_middle_reference_prune_dead_local_tees_in_body(
            then_, counts, options,
          ),
          match else_ {
            Some(else_body) =>
              Some(
                lower_middle_reference_prune_dead_local_tees_in_body(
                  else_body, counts, options,
                ),
              )
            None => None
          },
        ),
      )
    TryTable(bt, catches, Expr(body)) =>
      Some(
        Instruction::try_table(
          bt,
          catches,
          Expr::new(
            lower_middle_reference_prune_dead_local_tees_in_body(
              body, counts, options,
            ),
          ),
        ),
      )
    _ => Some(instr)
  }
}

///|
fn lower_middle_reference_prune_dead_local_tees_in_body(
  body : Array[Instruction],
  counts : Array[Int32],
  options : HotLowerOptions,
) -> Array[Instruction] {
  let pruned : Array[Instruction] = []
  for i = 0; i < body.length(); i = i + 1 {
    match body[i] {
      LocalTee(li) => {
        let @lib.LocalIdx(raw) = li
        let idx = raw.reinterpret_as_int()
        let dead = idx >= 0 && idx < counts.length() && counts[idx] == 0
        let mut preserve_dead_drop = false
        if dead &&
          options.preserve_dead_local_tee_drops &&
          i + 1 < body.length() {
          match body[i + 1] {
            Drop => preserve_dead_drop = true
            _ => ()
          }
        }
        if dead && !preserve_dead_drop {
          continue
        }
        pruned.push(body[i])
      }
      instr =>
        match
          lower_middle_reference_prune_dead_local_tees_in_instr(
            instr, counts, options,
          ) {
          Some(rewritten) => pruned.push(rewritten)
          None => ()
        }
    }
  }
  pruned
}

///|
fn lower_middle_reference_stackify_wrapped_struct_set_prefixes(
  func : HotFunc,
  body : Array[Instruction],
  extra_locals : Array[ValType],
  options : HotLowerOptions,
) -> Array[Instruction] {
  let rewritten : Array[Instruction] = []
  let mut idx = 0
  while idx < body.length() {
    if idx + 2 < body.length() {
      match body[idx] {
        Block(VoidBlockType, Expr(prefix_body)) =>
          if prefix_body.length() > 0 {
            match prefix_body[prefix_body.length() - 1] {
              Unreachable =>
                match body[idx + 1] {
                  LocalGet(source_local) =>
                    match body[idx + 2] {
                      LocalSet(target_local) | LocalTee(target_local) => {
                        let prefix_writes_source_local = hot_lower_impl_body_writes_local(
                          prefix_body, source_local,
                        )
                        let prefix_targets_removed_enclosing_label_deep = hot_lower_impl_body_targets_removed_label(
                          prefix_body, 2,
                        )
                        let prefix_targets_own_label_deep = hot_lower_impl_body_targets_own_label_from_min_depth(
                          prefix_body, 2,
                        )
                        if source_local != target_local &&
                          !hot_lower_impl_body_has_later_local_get(
                            body,
                            idx + 3,
                            source_local,
                          ) &&
                          !hot_lower_impl_body_targets_removed_label(
                            prefix_body, 1,
                          ) &&
                          !prefix_targets_own_label_deep &&
                          !(prefix_writes_source_local &&
                          prefix_targets_removed_enclosing_label_deep) {
                          match target_local {
                            LocalIdx(raw_local) => {
                              let local_id = raw_local.reinterpret_as_int()
                              match hot_local_type(func, local_id) {
                                Some(local_ty) => {
                                  let wrapped_body = hot_lower_impl_canonicalize_block_body(
                                    BlockType::val_type(local_ty),
                                    [body[idx], body[idx + 1]],
                                    HotLowerOptions::new(),
                                  )
                                  let wrapped_body = hot_lower_impl_expand_branch_depths_above(
                                    wrapped_body, -1,
                                  )
                                  rewritten.push(
                                    Instruction::block(
                                      BlockType::val_type(local_ty),
                                      Expr::new(wrapped_body),
                                    ),
                                  )
                                  rewritten.push(body[idx + 2])
                                  idx = idx + 3
                                  continue
                                }
                                None => ()
                              }
                            }
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
        _ => ()
      }
    }
    if !options.preserve_struct_set_value_blocks && idx + 2 < body.length() {
      match body[idx] {
        LocalGet(local_idx) =>
          match body[idx + 1] {
            Block(_, Expr(value_body)) =>
              match
                hot_lower_impl_stackify_struct_set_value_tail_start(value_body) {
                Some(tail_start) =>
                  match body[idx + 2] {
                    StructSet(_, _) =>
                      match local_idx {
                        LocalIdx(raw_local) => {
                          let local_id = raw_local.reinterpret_as_int()
                          match hot_local_type(func, local_id) {
                            Some(local_ty) => {
                              let scratch_local = LocalIdx::new(
                                (hot_local_count(func) + extra_locals.length()).reinterpret_as_uint(),
                              )
                              extra_locals.push(local_ty)
                              let wrapper_body : Array[Instruction] = [
                                Instruction::local_get(local_idx),
                                Instruction::local_set(scratch_local),
                              ]
                              for prefix_idx = 0
                                  prefix_idx < tail_start
                                  prefix_idx = prefix_idx + 1 {
                                wrapper_body.push(value_body[prefix_idx])
                              }
                              wrapper_body.push(
                                Instruction::local_get(scratch_local),
                              )
                              rewritten.push(
                                Instruction::block(
                                  BlockType::val_type(local_ty),
                                  Expr::new(
                                    hot_lower_impl_canonicalize_block_body(
                                      BlockType::val_type(local_ty),
                                      wrapper_body,
                                      HotLowerOptions::new(),
                                    ),
                                  ),
                                ),
                              )
                              for tail_idx = tail_start
                                  tail_idx < value_body.length()
                                  tail_idx = tail_idx + 1 {
                                rewritten.push(value_body[tail_idx])
                              }
                              rewritten.push(body[idx + 2])
                              idx = idx + 3
                              continue
                            }
                            None => ()
                          }
                        }
                      }
                    _ => ()
                  }
                None => ()
              }
            _ => ()
          }
        _ => ()
      }
    }
    rewritten.push(body[idx])
    idx = idx + 1
  }
  rewritten
}

///|
fn lower_middle_reference_stackify_nested_instr(
  func : HotFunc,
  instr : Instruction,
  extra_locals : Array[ValType],
  options : HotLowerOptions,
) -> Instruction {
  match instr {
    Block(bt, Expr(body)) =>
      Instruction::block(
        bt,
        Expr::new(
          lower_middle_reference_stackify_nested_body(
            func, body, extra_locals, options,
          ),
        ),
      )
    Loop(bt, Expr(body)) =>
      Instruction::loop_(
        bt,
        Expr::new(
          lower_middle_reference_stackify_nested_body(
            func, body, extra_locals, options,
          ),
        ),
      )
    If(bt, then_, else_) =>
      Instruction::if_(
        bt,
        lower_middle_reference_stackify_nested_body(
          func, then_, extra_locals, options,
        ),
        match else_ {
          Some(else_body) =>
            Some(
              lower_middle_reference_stackify_nested_body(
                func, else_body, extra_locals, options,
              ),
            )
          None => None
        },
      )
    TryTable(bt, catches, Expr(body)) =>
      Instruction::try_table(
        bt,
        catches,
        Expr::new(
          lower_middle_reference_stackify_nested_body(
            func, body, extra_locals, options,
          ),
        ),
      )
    _ => instr
  }
}

///|
fn lower_middle_reference_stackify_nested_body(
  func : HotFunc,
  body : Array[Instruction],
  extra_locals : Array[ValType],
  options : HotLowerOptions,
) -> Array[Instruction] {
  let rewritten_children : Array[Instruction] = []
  for instr in body {
    rewritten_children.push(
      lower_middle_reference_stackify_nested_instr(
        func, instr, extra_locals, options,
      ),
    )
  }
  lower_middle_reference_stackify_wrapped_struct_set_prefixes(
    func, rewritten_children, extra_locals, options,
  )
}

///|
fn lower_middle_reference_fix_split_payload_wrappers_in_instr(
  instr : Instruction,
) -> Instruction {
  match instr {
    Block(bt, Expr(body)) => {
      let fixed_body = lower_middle_reference_fix_split_payload_wrappers_in_body(
        body,
      )
      let fixed_body = match
        hot_lower_impl_try_fix_split_payload_wrapper_with_tail(bt, fixed_body) {
        Some(rewritten) => rewritten
        None => fixed_body
      }
      Instruction::block(bt, Expr::new(fixed_body))
    }
    Loop(bt, Expr(body)) =>
      Instruction::loop_(
        bt,
        Expr::new(
          lower_middle_reference_fix_split_payload_wrappers_in_body(body),
        ),
      )
    If(bt, then_, else_) =>
      Instruction::if_(
        bt,
        lower_middle_reference_fix_split_payload_wrappers_in_body(then_),
        match else_ {
          Some(else_body) =>
            Some(
              lower_middle_reference_fix_split_payload_wrappers_in_body(
                else_body,
              ),
            )
          None => None
        },
      )
    TryTable(bt, catches, Expr(body)) =>
      Instruction::try_table(
        bt,
        catches,
        Expr::new(
          lower_middle_reference_fix_split_payload_wrappers_in_body(body),
        ),
      )
    _ => instr
  }
}

///|
fn lower_middle_reference_fix_split_payload_wrappers_in_body(
  body : Array[Instruction],
) -> Array[Instruction] {
  let fixed : Array[Instruction] = []
  for instr in body {
    fixed.push(
      lower_middle_reference_fix_split_payload_wrappers_in_instr(instr),
    )
  }
  fixed
}
