///|
fn ssa_test_first_defined_func(
  mod_ : @lib.Module,
) -> (@lib.Locals, Array[@lib.Instruction]) raise {
  ssa_test_defined_func(mod_, 0)
}

///|
fn ssa_test_defined_func(
  mod_ : @lib.Module,
  defined_idx : Int,
) -> (@lib.Locals, Array[@lib.Instruction]) raise {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs.get(defined_idx) {
        Some(@lib.Func(locals, @lib.Expr(instrs))) => (locals, instrs)
        None => fail("expected defined function \{defined_idx}")
      }
    None => fail("expected code section")
  }
}

///|
fn ssa_test_collect_local_write_indices(
  instrs : Array[@lib.Instruction],
  out : Array[UInt],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.LocalSet(@lib.LocalIdx(idx)) | @lib.LocalTee(@lib.LocalIdx(idx)) =>
        out.push(idx)
      @lib.If(_, then_instrs, else_instrs) => {
        ssa_test_collect_local_write_indices(then_instrs, out)
        match else_instrs {
          Some(else_body) =>
            ssa_test_collect_local_write_indices(else_body, out)
          None => ()
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        ssa_test_collect_local_write_indices(body, out)
      _ => ()
    }
  }
}

///|
fn ssa_test_local_write_indices(
  instrs : Array[@lib.Instruction],
) -> Array[UInt] {
  let out : Array[UInt] = []
  ssa_test_collect_local_write_indices(instrs, out)
  out
}

///|
fn ssa_test_has_ssa_temp_local_writes(
  instrs : Array[@lib.Instruction],
  canonical_local : UInt,
) -> Bool {
  ssa_test_local_write_indices(instrs).any(fn(idx) { idx > canonical_local })
}

///|
fn ssa_test_has_adjacent_call_drop(
  instrs : Array[@lib.Instruction],
  target : UInt,
) -> Bool {
  for idx = 0; idx + 1 < instrs.length(); idx = idx + 1 {
    match (instrs[idx], instrs[idx + 1]) {
      (@lib.Call(@lib.FuncIdx(func_idx)), @lib.Drop) =>
        if func_idx == target {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_instrs_have_ref_null_branch_copy_lowering(
  instrs : Array[@lib.Instruction],
  canonical_local : UInt,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.If(_, then_body, Some(else_body)) => {
        let then_copies_canonical = ssa_test_local_write_indices(then_body).any(fn(
            idx,
          ) {
            idx == canonical_local
          },
        )
        let then_branches = then_body.any(fn(then_instr) {
          match then_instr {
            @lib.Br(_) => true
            _ => false
          }
        })
        if then_copies_canonical && then_branches {
          return true
        }
        if ssa_test_instrs_have_ref_null_branch_copy_lowering(
            then_body, canonical_local,
          ) ||
          ssa_test_instrs_have_ref_null_branch_copy_lowering(
            else_body, canonical_local,
          ) {
          return true
        }
      }
      @lib.If(_, then_body, None) => {
        let then_copies_canonical = ssa_test_local_write_indices(then_body).any(fn(
            idx,
          ) {
            idx == canonical_local
          },
        )
        let then_branches = then_body.any(fn(then_instr) {
          match then_instr {
            @lib.Br(_) => true
            _ => false
          }
        })
        if then_copies_canonical && then_branches {
          return true
        }
        if ssa_test_instrs_have_ref_null_branch_copy_lowering(
            then_body, canonical_local,
          ) {
          return true
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_ref_null_branch_copy_lowering(
            body, canonical_local,
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_instrs_have_ref_non_null_branch_copy_lowering(
  instrs : Array[@lib.Instruction],
  canonical_local : UInt,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.If(_, then_body, Some(else_body)) => {
        let else_copies_canonical = ssa_test_local_write_indices(else_body).any(fn(
            idx,
          ) {
            idx == canonical_local
          },
        )
        let else_restores_non_null = else_body.any(fn(else_instr) {
          else_instr == @lib.Instruction::ref_as_non_null()
        })
        let else_branches = else_body.any(fn(else_instr) {
          match else_instr {
            @lib.Br(_) => true
            _ => false
          }
        })
        if else_copies_canonical && else_restores_non_null && else_branches {
          return true
        }
        if ssa_test_instrs_have_ref_non_null_branch_copy_lowering(
            then_body, canonical_local,
          ) ||
          ssa_test_instrs_have_ref_non_null_branch_copy_lowering(
            else_body, canonical_local,
          ) {
          return true
        }
      }
      @lib.If(_, then_body, None) =>
        if ssa_test_instrs_have_ref_non_null_branch_copy_lowering(
            then_body, canonical_local,
          ) {
          return true
        }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_ref_non_null_branch_copy_lowering(
            body, canonical_local,
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_divergent_i32_local_prefix(
  local_idx : @lib.LocalIdx,
) -> Array[@lib.Instruction] {
  [
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::i32_const(@lib.I32::new(7)),
        @lib.Instruction::local_set(local_idx),
      ],
      Some([
        @lib.Instruction::i32_const(@lib.I32::new(8)),
        @lib.Instruction::local_set(local_idx),
      ]),
    ),
  ]
}

///|
// Raw-path boundary: GC/reference branch operands are not hot-mutated, but the
// raw lowering must still materialize the required Starshine-owned branch-copy
// shape. This is not a green no-op: the structural assertions below prove the
// observable no-merge copy lowering is present.
fn ssa_test_assert_raw_ref_branch_copy_lowering(
  input : @lib.Module,
  canonical_local : UInt,
  branch_on_non_null : Bool,
  context : String,
) -> Unit raise {
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected \{context} ssa-nomerge success, got \{err}")
  }

  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("hot-lift-error") }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  if branch_on_non_null {
    assert_true(
      ssa_test_instrs_have_ref_non_null_branch_copy_lowering(
        instrs, canonical_local,
      ),
      msg=instrs.to_string(),
    )
  } else {
    assert_true(
      ssa_test_instrs_have_ref_null_branch_copy_lowering(
        instrs, canonical_local,
      ),
      msg=instrs.to_string(),
    )
  }
}

///|
fn ssa_test_instrs_have_loop_param_cast_proxy(
  instrs : Array[@lib.Instruction],
  expect_fail_variant : Bool,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Loop(@lib.VoidBlockType, @lib.Expr(loop_body)) =>
        for loop_instr in loop_body {
          match loop_instr {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) => {
              let has_loop_backedge = outer_body.any(fn(outer_instr) {
                outer_instr == @lib.Instruction::br(@lib.LabelIdx::new(1U))
              })
              let has_inner_cast_proxy = outer_body.any(fn(outer_instr) {
                match outer_instr {
                  @lib.Block(@lib.ValTypeBlockType(_), @lib.Expr(inner_body)) =>
                    inner_body.any(fn(inner_instr) {
                      match inner_instr {
                        @lib.BrOnCastFail(@lib.LabelIdx(raw), _, _, _) =>
                          expect_fail_variant && raw == 0U
                        @lib.BrOnCast(@lib.LabelIdx(raw), _, _, _) =>
                          !expect_fail_variant && raw == 0U
                        _ => false
                      }
                    })
                  _ => false
                }
              })
              if has_loop_backedge && has_inner_cast_proxy {
                return true
              }
            }
            _ => ()
          }
        }
      @lib.Block(_, @lib.Expr(body)) | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_loop_param_cast_proxy(body, expect_fail_variant) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_loop_param_cast_proxy(
            then_body, expect_fail_variant,
          ) {
          return true
        }
        match else_body {
          Some(body) =>
            if ssa_test_instrs_have_loop_param_cast_proxy(
                body, expect_fail_variant,
              ) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_instrs_have_loop_param_scalar_br_proxy(
  instrs : Array[@lib.Instruction],
) -> Bool {
  ssa_test_instrs_have_loop_param_scalar_branch_proxy(instrs, false)
}

///|
fn ssa_test_instrs_have_loop_param_scalar_br_if_proxy(
  instrs : Array[@lib.Instruction],
) -> Bool {
  ssa_test_instrs_have_loop_param_scalar_branch_proxy(instrs, true)
}

///|
fn ssa_test_instrs_have_multi_param_loop_store_backedge(
  instrs : Array[@lib.Instruction],
) -> Bool {
  fn body_has_loop_backedge(
    body : Array[@lib.Instruction],
    depth : UInt,
  ) -> Bool {
    for instr in body {
      match instr {
        @lib.Br(@lib.LabelIdx(raw)) => if raw == depth { return true }
        @lib.Block(_, @lib.Expr(nested_body))
        | @lib.Loop(_, @lib.Expr(nested_body))
        | @lib.TryTable(_, _, @lib.Expr(nested_body)) =>
          if body_has_loop_backedge(nested_body, depth + 1U) {
            return true
          }
        @lib.If(_, then_body, else_body) => {
          if body_has_loop_backedge(then_body, depth + 1U) {
            return true
          }
          match else_body {
            Some(body) =>
              if body_has_loop_backedge(body, depth + 1U) {
                return true
              }
            None => ()
          }
        }
        _ => ()
      }
    }
    false
  }
  for instr in instrs {
    match instr {
      @lib.Loop(@lib.VoidBlockType, @lib.Expr(loop_body)) =>
        if body_has_loop_backedge(loop_body, 0U) {
          return true
        }
      @lib.Block(_, @lib.Expr(body)) | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_multi_param_loop_store_backedge(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_multi_param_loop_store_backedge(then_body) {
          return true
        }
        match else_body {
          Some(body) =>
            if ssa_test_instrs_have_multi_param_loop_store_backedge(body) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_instrs_have_loop_param_br_table_proxy(
  instrs : Array[@lib.Instruction],
) -> Bool {
  fn body_has_br_table_depth(
    body : Array[@lib.Instruction],
    depth : UInt,
  ) -> Bool {
    for instr in body {
      match instr {
        @lib.BrTable(labels, @lib.LabelIdx(default_raw)) => {
          let mut all_targets_match = default_raw == depth
          for label in labels {
            let @lib.LabelIdx(raw) = label
            if raw != depth {
              all_targets_match = false
            }
          }
          if all_targets_match {
            return true
          }
        }
        @lib.Block(_, @lib.Expr(nested_body))
        | @lib.Loop(_, @lib.Expr(nested_body))
        | @lib.TryTable(_, _, @lib.Expr(nested_body)) =>
          if body_has_br_table_depth(nested_body, depth + 1U) {
            return true
          }
        @lib.If(_, then_body, else_body) => {
          if body_has_br_table_depth(then_body, depth + 1U) {
            return true
          }
          match else_body {
            Some(body) =>
              if body_has_br_table_depth(body, depth + 1U) {
                return true
              }
            None => ()
          }
        }
        _ => ()
      }
    }
    false
  }
  for instr in instrs {
    match instr {
      @lib.Loop(@lib.VoidBlockType, @lib.Expr(loop_body)) =>
        for loop_instr in loop_body {
          match loop_instr {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) => {
              let has_loop_backedge = outer_body.any(fn(outer_instr) {
                outer_instr == @lib.Instruction::br(@lib.LabelIdx::new(1U))
              })
              let has_inner_table_proxy = outer_body.any(fn(outer_instr) {
                match outer_instr {
                  @lib.Block(@lib.ValTypeBlockType(_), @lib.Expr(inner_body)) =>
                    body_has_br_table_depth(inner_body, 0U)
                  _ => false
                }
              })
              if has_loop_backedge && has_inner_table_proxy {
                return true
              }
            }
            _ => ()
          }
        }
      @lib.Block(_, @lib.Expr(body)) | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_loop_param_br_table_proxy(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_loop_param_br_table_proxy(then_body) {
          return true
        }
        match else_body {
          Some(body) =>
            if ssa_test_instrs_have_loop_param_br_table_proxy(body) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_instrs_have_loop_param_scalar_branch_proxy(
  instrs : Array[@lib.Instruction],
  expect_br_if : Bool,
) -> Bool {
  fn body_has_branch_depth(
    body : Array[@lib.Instruction],
    depth : UInt,
  ) -> Bool {
    for instr in body {
      match instr {
        @lib.Br(@lib.LabelIdx(raw)) =>
          if !expect_br_if && raw == depth {
            return true
          }
        @lib.BrIf(@lib.LabelIdx(raw)) =>
          if expect_br_if && raw == depth {
            return true
          }
        @lib.Block(_, @lib.Expr(nested_body))
        | @lib.Loop(_, @lib.Expr(nested_body))
        | @lib.TryTable(_, _, @lib.Expr(nested_body)) =>
          if body_has_branch_depth(nested_body, depth + 1U) {
            return true
          }
        @lib.If(_, then_body, else_body) => {
          if body_has_branch_depth(then_body, depth + 1U) {
            return true
          }
          match else_body {
            Some(body) =>
              if body_has_branch_depth(body, depth + 1U) {
                return true
              }
            None => ()
          }
        }
        _ => ()
      }
    }
    false
  }
  for instr in instrs {
    match instr {
      @lib.Loop(@lib.VoidBlockType, @lib.Expr(loop_body)) => {
        for loop_instr in loop_body {
          match loop_instr {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) => {
              let has_loop_backedge = outer_body.any(fn(outer_instr) {
                outer_instr == @lib.Instruction::br(@lib.LabelIdx::new(1U))
              })
              let has_inner_branch_proxy = outer_body.any(fn(outer_instr) {
                match outer_instr {
                  @lib.Block(@lib.ValTypeBlockType(_), @lib.Expr(inner_body)) =>
                    body_has_branch_depth(inner_body, 0U)
                  _ => false
                }
              })
              if has_loop_backedge && has_inner_branch_proxy {
                return true
              }
            }
            _ => ()
          }
        }
        if ssa_test_instrs_have_loop_param_scalar_branch_proxy(
            loop_body, expect_br_if,
          ) {
          return true
        }
      }
      @lib.Block(block_type, @lib.Expr(body)) => {
        if !expect_br_if && block_type != @lib.BlockType::void_() {
          for block_instr in body {
            match block_instr {
              @lib.Loop(@lib.VoidBlockType, @lib.Expr(loop_body)) =>
                if body_has_branch_depth(loop_body, 1U) {
                  return true
                }
              _ => ()
            }
          }
        }
        if expect_br_if && block_type == @lib.BlockType::void_() {
          for block_instr in body {
            match block_instr {
              @lib.Loop(@lib.VoidBlockType, @lib.Expr(loop_body)) =>
                if body_has_branch_depth(loop_body, 0U) &&
                  loop_body.any(fn(loop_instr) {
                    match loop_instr {
                      @lib.LocalSet(_) | @lib.LocalTee(_) => true
                      _ => false
                    }
                  }) {
                  return true
                }
              _ => ()
            }
          }
        }
        if ssa_test_instrs_have_loop_param_scalar_branch_proxy(
            body, expect_br_if,
          ) {
          return true
        }
      }
      @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_loop_param_scalar_branch_proxy(
            body, expect_br_if,
          ) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_loop_param_scalar_branch_proxy(
            then_body, expect_br_if,
          ) {
          return true
        }
        match else_body {
          Some(body) =>
            if ssa_test_instrs_have_loop_param_scalar_branch_proxy(
                body, expect_br_if,
              ) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_instrs_have_loop_param_null_proxy(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Loop(@lib.VoidBlockType, @lib.Expr(loop_body)) =>
        for loop_instr in loop_body {
          match loop_instr {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) => {
              let has_loop_backedge = outer_body.any(fn(outer_instr) {
                outer_instr == @lib.Instruction::br(@lib.LabelIdx::new(1U))
              })
              let has_inner_null_proxy = outer_body.any(fn(outer_instr) {
                match outer_instr {
                  @lib.Block(@lib.ValTypeBlockType(_), @lib.Expr(inner_body)) =>
                    inner_body.any(fn(inner_instr) {
                      match inner_instr {
                        @lib.BrOnNull(@lib.LabelIdx(raw)) => raw == 0U
                        _ => false
                      }
                    })
                  _ => false
                }
              })
              if has_loop_backedge && has_inner_null_proxy {
                return true
              }
            }
            _ => ()
          }
        }
      @lib.Block(_, @lib.Expr(body)) | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_loop_param_null_proxy(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_loop_param_null_proxy(then_body) {
          return true
        }
        match else_body {
          Some(body) =>
            if ssa_test_instrs_have_loop_param_null_proxy(body) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_instrs_have_null_taken_copy_branch(
  instrs : Array[@lib.Instruction],
  canonical_local : UInt,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.If(_, then_body, else_body) => {
        let then_copies_canonical = ssa_test_local_write_indices(then_body).any(fn(
            idx,
          ) {
            idx == canonical_local
          },
        )
        let then_branches = then_body.any(fn(then_instr) {
          match then_instr {
            @lib.Br(_) => true
            _ => false
          }
        })
        if then_copies_canonical && then_branches {
          return true
        }
        if ssa_test_instrs_have_null_taken_copy_branch(
            then_body, canonical_local,
          ) {
          return true
        }
        match else_body {
          Some(body) =>
            if ssa_test_instrs_have_null_taken_copy_branch(
                body, canonical_local,
              ) {
              return true
            }
          None => ()
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_null_taken_copy_branch(body, canonical_local) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_instrs_have_loop_param_non_null_proxy(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Loop(@lib.VoidBlockType, @lib.Expr(loop_body)) =>
        for loop_instr in loop_body {
          match loop_instr {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) => {
              let has_loop_backedge = outer_body.any(fn(outer_instr) {
                outer_instr == @lib.Instruction::br(@lib.LabelIdx::new(1U))
              })
              let has_inner_non_null_proxy = outer_body.any(fn(outer_instr) {
                match outer_instr {
                  @lib.Block(@lib.ValTypeBlockType(_), @lib.Expr(inner_body)) =>
                    inner_body.any(fn(inner_instr) {
                      match inner_instr {
                        @lib.BrOnNonNull(@lib.LabelIdx(raw)) => raw == 0U
                        _ => false
                      }
                    })
                  _ => false
                }
              })
              if has_loop_backedge && has_inner_non_null_proxy {
                return true
              }
            }
            _ => ()
          }
        }
      @lib.Block(_, @lib.Expr(body)) | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_loop_param_non_null_proxy(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_loop_param_non_null_proxy(then_body) {
          return true
        }
        match else_body {
          Some(body) =>
            if ssa_test_instrs_have_loop_param_non_null_proxy(body) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_instrs_have_ref_cast_branch_copy_block(
  instrs : Array[@lib.Instruction],
  canonical_local : UInt,
  expect_fail_variant : Bool,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Block(_, @lib.Expr(body)) => {
        let has_inverse_cast = body.any(fn(body_instr) {
          match body_instr {
            @lib.BrOnCast(@lib.LabelIdx(label), _, _, _) =>
              !expect_fail_variant && label == 0U
            @lib.BrOnCastFail(@lib.LabelIdx(label), _, _, _) =>
              expect_fail_variant && label == 0U
            _ => false
          }
        })
        let copies_canonical = ssa_test_local_write_indices(body).any(fn(idx) {
          idx == canonical_local
        })
        let exits_outer = body.any(fn(body_instr) {
          match body_instr {
            @lib.Br(@lib.LabelIdx(label)) => label > 0U
            _ => false
          }
        })
        if has_inverse_cast && copies_canonical && exits_outer {
          return true
        }
        if ssa_test_instrs_have_ref_cast_branch_copy_block(
            body, canonical_local, expect_fail_variant,
          ) {
          return true
        }
      }
      @lib.Loop(_, @lib.Expr(body)) | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_test_instrs_have_ref_cast_branch_copy_block(
            body, canonical_local, expect_fail_variant,
          ) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if ssa_test_instrs_have_ref_cast_branch_copy_block(
            then_body, canonical_local, expect_fail_variant,
          ) {
          return true
        }
        match else_body {
          Some(body) =>
            if ssa_test_instrs_have_ref_cast_branch_copy_block(
                body, canonical_local, expect_fail_variant,
              ) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_run_hot_path_only(text : String) -> Result[@lib.Module, String] {
  let mod_ = pass_test_module_from_wat(text)
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  @ir.hot_verify_all_or_abort(func)
  let ctx = HotPassContext::new(
    ssa_nomerge_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) => return Err("ssa-nomerge hot-path run failed: \{err}")
  }
  let lowered = @ir.hot_lower_func_with_options(
    func,
    @ir.HotLowerOptions::new(preserve_dead_local_tee_drops=true),
  )
  let next_code_sec = match mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[0] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => return Err("expected code sec in hot-path fixture")
  }
  let out = mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => Ok(out)
    Err(err) => Err(@validate.validation_error_message(err))
  }
}

///|
test "ssa-nomerge artifact parity allocates fresh locals for value if after body-local writes" {
  // Artifact repro from
  // `.tmp/self-ssa-nomerge-debug-wasi-bronull-prefix-subtype-results`, first
  // canonical difference `defined=0 abs=27`. Binaryen's `ssa-nomerge`
  // leaves the original body-local slot behind and appends fresh SSA temporaries
  // for body-local scratch writes inside the value-producing `if` before the
  // later `local.tee`. Keep that shape so the artifact gap does not regress.
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    (local i32)
    #|    local.get 1
    #|    i32.const 256
    #|    i32.lt_u
    #|    if (result i32)
    #|      local.get 1
    #|      i32.const 4
    #|      i32.shr_u
    #|      local.set 1
    #|      i32.const 0
    #|    else
    #|      local.get 1
    #|      i32.const 536870910
    #|      i32.lt_u
    #|      if
    #|        local.get 1
    #|        i32.const 1
    #|        i32.const 27
    #|        local.get 1
    #|        i32.clz
    #|        i32.sub
    #|        i32.shl
    #|        i32.add
    #|        i32.const 1
    #|        i32.sub
    #|        local.set 1
    #|      end
    #|      i32.const 31
    #|      local.get 1
    #|      i32.clz
    #|      i32.sub
    #|      local.set 2
    #|      local.get 1
    #|      local.get 2
    #|      i32.const 4
    #|      i32.sub
    #|      i32.shr_u
    #|      i32.const 16
    #|      i32.xor
    #|      local.set 1
    #|      local.get 2
    #|      i32.const 7
    #|      i32.sub
    #|    end
    #|    local.tee 2
    #|    local.get 1
    #|    i32.add))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() >= 3, msg=locals.to_string())
  assert_true(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx == 4U }),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge artifact parity freshens parameter scratch writes in nested unlink" {
  // Artifact repro reduced from
  // `.tmp/self-ssa-nomerge-debug-wasi-bronull-prefix-subtype-results`, sampled
  // canonical difference `defined=0 abs=28` (`tlsf/removeBlock`). Binaryen does
  // not write back to parameter locals for nested unlink scratch values; it
  // appends fresh body locals for the address and masked-word temporaries. A
  // raw Starshine reuse of `param 1` has no measured win, so keep Binaryen's
  // no-parameter-write shape for this family.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func (param i32 i32)
    #|    (local i32 i32 i32 i32)
    #|    local.get 1
    #|    i32.load
    #|    i32.const -4
    #|    i32.and
    #|    local.tee 2
    #|    i32.const 256
    #|    i32.lt_u
    #|    if (result i32)
    #|      local.get 2
    #|      i32.const 4
    #|      i32.shr_u
    #|      local.set 3
    #|      i32.const 0
    #|    else
    #|      i32.const 31
    #|      local.get 2
    #|      i32.clz
    #|      i32.sub
    #|      local.set 2
    #|      local.get 2
    #|      i32.const 7
    #|      i32.sub
    #|    end
    #|    local.set 5
    #|    local.get 1
    #|    i32.load offset=8
    #|    local.set 2
    #|    local.get 1
    #|    i32.load offset=4
    #|    local.tee 4
    #|    if
    #|      local.get 4
    #|      local.get 2
    #|      i32.store offset=8
    #|      local.get 2
    #|      if
    #|        local.get 2
    #|        local.get 4
    #|        i32.store offset=4
    #|        local.get 0
    #|        local.get 5
    #|        i32.const 2
    #|        i32.shl
    #|        i32.add
    #|        local.tee 1
    #|        local.get 1
    #|        i32.load offset=4
    #|        i32.const -2
    #|        local.get 3
    #|        i32.rotl
    #|        i32.and
    #|        local.tee 1
    #|        i32.store offset=4
    #|        local.get 1
    #|        i32.eqz
    #|        if
    #|          local.get 0
    #|          local.get 0
    #|          i32.load
    #|          i32.const -2
    #|          local.get 5
    #|          i32.rotl
    #|          i32.and
    #|          i32.store
    #|        end
    #|      end
    #|    end))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() >= 6, msg=locals.to_string())
  assert_false(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx < 2U }),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge artifact parity freshens split-memory body scratch locals" {
  // Artifact repro reduced from
  // `.tmp/self-ssa-nomerge-debug-wasi-bronull-prefix-subtype-results`, sampled
  // canonical difference `defined=0 abs=30`. Binaryen freshens the derived split
  // size and new-block address temporaries before the nested stores and call;
  // Starshine reused one body-local scratch for all of them with no proven win.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $insertBlock (param i32 i32))
    #|  (func (param i32 i32 i64)
    #|    (local i32 i32 i32)
    #|    local.get 0
    #|    i32.load offset=1568
    #|    local.tee 4
    #|    i32.const 0
    #|    local.get 1
    #|    i32.const 19
    #|    i32.add
    #|    i32.const -16
    #|    i32.and
    #|    i32.const 4
    #|    i32.sub
    #|    local.tee 1
    #|    i32.const 16
    #|    i32.sub
    #|    local.tee 3
    #|    local.get 4
    #|    i32.eq
    #|    select
    #|    if
    #|      local.get 4
    #|      i32.load
    #|      local.set 5
    #|      local.get 3
    #|      local.set 1
    #|      local.get 2
    #|      i32.wrap_i64
    #|      i32.const -16
    #|      i32.and
    #|      local.get 1
    #|      i32.sub
    #|      local.tee 3
    #|      i32.const 20
    #|      i32.lt_u
    #|      if
    #|        return
    #|      end
    #|      local.get 1
    #|      local.get 5
    #|      i32.const 2
    #|      i32.and
    #|      local.get 3
    #|      i32.const 8
    #|      i32.sub
    #|      local.tee 3
    #|      i32.const 1
    #|      i32.or
    #|      i32.or
    #|      i32.store
    #|      local.get 1
    #|      i32.const 0
    #|      i32.store offset=4
    #|      local.get 1
    #|      i32.const 0
    #|      i32.store offset=8
    #|      local.get 1
    #|      i32.const 4
    #|      i32.add
    #|      local.get 3
    #|      i32.add
    #|      local.tee 3
    #|      i32.const 2
    #|      i32.store
    #|      local.get 0
    #|      local.get 3
    #|      i32.store offset=1568
    #|      local.get 0
    #|      local.get 1
    #|      call $insertBlock
    #|    end))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() >= 7, msg=locals.to_string())
  assert_false(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx == 3U }),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge artifact parity freshens tee-set loop base scratch" {
  // Artifact repro reduced from
  // `.tmp/self-ssa-nomerge-debug-wasi-bronull-prefix-subtype-results`, sampled
  // canonical difference `defined=0 abs=50` (`moonbit.unsafe_make_string`).
  // Binaryen keeps the allocation result tee and the loop base pointer in
  // separate fresh locals before the store loop; Starshine reused the original
  // body-local slot with no proven benefit.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $make (param i32) (result i32)
    #|    local.get 0)
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32)
    #|    local.get 0
    #|    call $make
    #|    local.tee 2
    #|    local.set 2
    #|    loop
    #|      local.get 3
    #|      local.get 0
    #|      i32.lt_s
    #|      if
    #|        local.get 2
    #|        local.get 3
    #|        i32.const 1
    #|        i32.shl
    #|        i32.add
    #|        local.get 1
    #|        i32.store16 offset=8 align=1
    #|        local.get 3
    #|        i32.const 1
    #|        i32.add
    #|        local.set 3
    #|        br 1
    #|      end
    #|    end
    #|    local.get 2))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() >= 4, msg=locals.to_string())
  assert_true(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx == 5U }),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx == 2U }),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge artifact parity freshens memory growth page temporaries only" {
  // Artifact repro reduced from
  // `.tmp/self-ssa-nomerge-debug-wasi-bronull-prefix-subtype-results`, sampled
  // canonical difference `defined=0 abs=31` (`tlsf/initialize`). Binaryen
  // freshens the pre-loop memory-size/page-count temps but keeps the loop
  // induction locals canonical; do not let repeated-store freshening spill the
  // induction locals beyond Binaryen's local budget.
  let source =
    #|(module
    #|  (memory 1)
    #|  (global (mut i32) (i32.const 0))
    #|  (func $addMemory (param i32 i32 i64))
    #|  (func
    #|    (local i32 i32 i32)
    #|    i32.const 220368
    #|    i32.const 15
    #|    i32.add
    #|    i32.const -16
    #|    i32.and
    #|    local.set 0
    #|    memory.size
    #|    local.tee 1
    #|    local.get 0
    #|    i32.const 67107
    #|    i32.add
    #|    i32.const -65536
    #|    i32.and
    #|    i32.const 16
    #|    i32.shr_u
    #|    local.tee 2
    #|    i32.lt_s
    #|    if (result i32)
    #|      local.get 2
    #|      local.get 1
    #|      i32.sub
    #|      memory.grow
    #|      i32.const 0
    #|      i32.lt_s
    #|    else
    #|      i32.const 0
    #|    end
    #|    if
    #|      unreachable
    #|    else
    #|      local.get 0
    #|      i32.const 0
    #|      i32.store
    #|      local.get 0
    #|      i32.const 0
    #|      i32.store offset=1568
    #|      i32.const 0
    #|      local.set 1
    #|      loop
    #|        local.get 1
    #|        i32.const 23
    #|        i32.lt_u
    #|        if
    #|          local.get 0
    #|          local.get 1
    #|          i32.const 2
    #|          i32.shl
    #|          i32.add
    #|          i32.const 0
    #|          i32.store offset=4
    #|          i32.const 0
    #|          local.set 2
    #|          loop
    #|            local.get 2
    #|            i32.const 16
    #|            i32.lt_u
    #|            if
    #|              local.get 0
    #|              local.get 1
    #|              i32.const 4
    #|              i32.shl
    #|              local.get 2
    #|              i32.add
    #|              i32.const 2
    #|              i32.shl
    #|              i32.add
    #|              i32.const 0
    #|              i32.store offset=96
    #|              local.get 2
    #|              i32.const 1
    #|              i32.add
    #|              local.set 2
    #|              br 1
    #|            end
    #|          end
    #|          local.get 1
    #|          i32.const 1
    #|          i32.add
    #|          local.set 1
    #|          br 1
    #|        end
    #|      end
    #|      local.get 0
    #|      local.get 0
    #|      i32.const 1572
    #|      i32.add
    #|      memory.size
    #|      i64.extend_i32_s
    #|      i64.const 16
    #|      i64.shl
    #|      call $addMemory
    #|      local.get 0
    #|      global.set 0
    #|    end))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() >= 5, msg=locals.to_string())
  assert_false(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx > 4U }),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx == 3U }) &&
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx == 4U }),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge artifact parity freshens table growth slot temporaries" {
  // Artifact repro reduced from
  // `.tmp/self-ssa-nomerge-debug-wasi-bronull-prefix-subtype-results`, sampled
  // canonical difference `defined=0 abs=59` (`moonbit.alloc_externref`).
  // Binaryen freshens the table size and allocated slot temporaries around the
  // table growth/free-list update while preserving the grow-count loop local.
  let source =
    #|(module
    #|  (memory 1)
    #|  (table 0 externref)
    #|  (global (mut i32) (i32.const -1))
    #|  (func $malloc (param i32) (result i32)
    #|    local.get 0)
    #|  (func $alloc (param i32) (result i32)
    #|    local.get 0)
    #|  (func (param externref) (result i32)
    #|    (local i32 i32 i32 i32 i32)
    #|    global.get 0
    #|    local.tee 1
    #|    i32.const 0
    #|    i32.lt_s
    #|    if
    #|      table.size 0
    #|      local.set 3
    #|      local.get 3
    #|      i32.eqz
    #|      if (result i32)
    #|        i32.const 16
    #|      else
    #|        local.get 3
    #|        i32.const 1
    #|        i32.shl
    #|      end
    #|      local.set 5
    #|      ref.null extern
    #|      local.get 5
    #|      table.grow 0
    #|      i32.const 0
    #|      i32.lt_s
    #|      if
    #|        unreachable
    #|      end
    #|      loop
    #|        local.get 5
    #|        local.get 3
    #|        i32.gt_s
    #|        if
    #|          local.get 5
    #|          i32.const 1
    #|          i32.sub
    #|          local.set 5
    #|          i32.const 8
    #|          call $malloc
    #|          local.tee 2
    #|          local.get 5
    #|          i32.store
    #|          local.get 2
    #|          local.get 1
    #|          i32.store offset=4
    #|          local.get 2
    #|          local.set 1
    #|          br 1
    #|        end
    #|      end
    #|    end
    #|    local.get 1
    #|    i32.load offset=4
    #|    global.set 0
    #|    local.get 1
    #|    i32.load
    #|    local.set 3
    #|    local.get 3
    #|    local.get 0
    #|    table.set 0
    #|    i32.const 4
    #|    call $alloc
    #|    local.tee 4
    #|    i32.const 3
    #|    i32.const 30
    #|    i32.shl
    #|    i32.store offset=4
    #|    local.get 4
    #|    local.get 3
    #|    i32.store offset=8
    #|    local.get 4)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 2)
  assert_true(locals.length() >= 7, msg=locals.to_string())
  assert_true(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx == 6U }) &&
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx == 7U }),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx == 3U }),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge artifact parity keeps loop-carried result update in canonical local" {
  // Artifact repro reduced from
  // `.tmp/self-ssa-nomerge-debug-wasi-bronull-prefix-subtype-results`, sampled
  // canonical difference `defined=0 abs=37`. Binaryen rewrites the loop-carried
  // update with only the original body-local slot (`local 2`); Starshine used
  // to spill `local.get 2` through an unnecessary extra temp (`local 3`), adding
  // one local and one write with no proven Starshine benefit.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $id (param i32) (result i32)
    #|    local.get 0)
    #|  (func (param i32 i32) (result i32)
    #|    (local i32)
    #|    local.get 0
    #|    call $id
    #|    local.get 1
    #|    call $id
    #|    i32.eq
    #|    if (result i32)
    #|      loop (result i32)
    #|        local.get 2
    #|        local.get 0
    #|        call $id
    #|        i32.lt_s
    #|        if (result i32)
    #|          local.get 0
    #|          local.get 2
    #|          i32.const 1
    #|          i32.shl
    #|          i32.add
    #|          i32.load16_u offset=8 align=1
    #|          local.get 1
    #|          local.get 2
    #|          i32.const 1
    #|          i32.shl
    #|          i32.add
    #|          i32.load16_u offset=8 align=1
    #|          i32.eq
    #|          if (result i32)
    #|            local.get 2
    #|            i32.const 1
    #|            i32.add
    #|            local.set 2
    #|            br 2
    #|          else
    #|            i32.const 0
    #|            return
    #|          end
    #|        else
    #|          i32.const 1
    #|          return
    #|        end
    #|      end
    #|    else
    #|      i32.const 0
    #|      return
    #|    end))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(locals.length() <= 1, msg=locals.to_string())
  assert_false(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx == 3U }),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge artifact parity keeps gc free branch exits at Binaryen local budget" {
  // Artifact repro from
  // `.tmp/self-ssa-nomerge-debug-wasi-bronull-prefix-subtype-results`, sampled
  // canonical difference `defined=0 abs=57` (`moonbit.gc.free`). The saved
  // artifact has no typed result loop, so it is distinct from the abs37 loop
  // result guard: Binaryen appends four body locals for this branch-heavy free
  // walk, while Starshine used to append six. Until a measured Starshine win is
  // proven, keep the Binaryen local budget shape.
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $moonbit.decref (param i32))
    #|  (func $moonbit.drop_externref (param i32))
    #|  (func $moonbit.free (param i32))
    #|  (func $moonbit.gc.free (param $ptr i32)
    #|    (local $parent i32) (local $curr_child_offset i32) (local $remaining_children_count i32)
    #|    (local $n_ptr_fields i32) (local $ptr_fields_offset i32) (local $kind i32)
    #|    (local $ref_array_kind i32) (local $vt_ptr i32) (local $vt_ptr_index i32)
    #|    (local $vt_ptr_fields_offset i32) (local $vt_n_ptr_fields i32) (local $vt_header i32)
    #|    (local $meta i32) (local $next i32) (local $addr_of_next i32) (local $len i32) (local $count i32)
    #|    loop
    #|      local.get $ptr
    #|      i32.load offset=4 align=1
    #|      local.tee $meta
    #|      i32.const 30
    #|      i32.shr_u
    #|      local.set $kind
    #|      block
    #|        i32.const 0
    #|        local.get $kind
    #|        i32.eq
    #|        if
    #|          local.get $meta
    #|          i32.const 8
    #|          i32.shr_u
    #|          i32.const 2047
    #|          i32.and
    #|          local.tee $n_ptr_fields
    #|          i32.eqz
    #|          if
    #|          else
    #|            local.get $meta
    #|            i32.const 19
    #|            i32.shr_u
    #|            i32.const 2047
    #|            i32.and
    #|            local.set $ptr_fields_offset
    #|            local.get $ptr_fields_offset
    #|            local.set $curr_child_offset
    #|            local.get $n_ptr_fields
    #|            local.set $remaining_children_count
    #|            br 2
    #|          end
    #|        else
    #|          i32.const 2
    #|          local.get $kind
    #|          i32.eq
    #|          if
    #|            i32.const 3
    #|            local.get $meta
    #|            i32.const 28
    #|            i32.shr_u
    #|            i32.and
    #|            local.set $ref_array_kind
    #|            i32.const 1
    #|            local.get $ref_array_kind
    #|            i32.eq
    #|            if
    #|              local.get $meta
    #|              i32.const 268435455
    #|              i32.and
    #|              local.set $len
    #|              local.get $ptr
    #|              i32.const 8
    #|              i32.add
    #|              local.set $vt_ptr
    #|              local.get $vt_ptr
    #|              i32.load align=1
    #|              local.set $vt_header
    #|              i32.const 2047
    #|              local.get $vt_header
    #|              i32.const 8
    #|              i32.shr_u
    #|              i32.and
    #|              local.set $vt_n_ptr_fields
    #|              i32.const 2047
    #|              local.get $vt_header
    #|              i32.const 19
    #|              i32.shr_u
    #|              i32.and
    #|              local.set $vt_ptr_fields_offset
    #|              local.get $vt_ptr
    #|              i32.const 4
    #|              i32.add
    #|              local.set $vt_ptr
    #|              loop
    #|                local.get $len
    #|                i32.const 0
    #|                i32.gt_s
    #|                if
    #|                  local.get $len
    #|                  i32.const 1
    #|                  i32.sub
    #|                  local.set $len
    #|                  i32.const 0
    #|                  local.set $vt_ptr_index
    #|                  local.get $vt_ptr
    #|                  local.get $vt_ptr_fields_offset
    #|                  i32.const 4
    #|                  i32.mul
    #|                  i32.add
    #|                  local.set $vt_ptr
    #|                  loop
    #|                    local.get $vt_ptr_index
    #|                    local.get $vt_n_ptr_fields
    #|                    i32.lt_s
    #|                    if
    #|                      local.get $vt_ptr
    #|                      i32.load align=1
    #|                      i32.const 0
    #|                      i32.ne
    #|                      if
    #|                        local.get $vt_ptr
    #|                        i32.load align=1
    #|                        call $moonbit.decref
    #|                      end
    #|                      local.get $vt_ptr_index
    #|                      i32.const 1
    #|                      i32.add
    #|                      local.set $vt_ptr_index
    #|                      local.get $vt_ptr
    #|                      i32.const 4
    #|                      i32.add
    #|                      local.set $vt_ptr
    #|                      br 1
    #|                    end
    #|                  end
    #|                  br 1
    #|                end
    #|              end
    #|            else
    #|              local.get $meta
    #|              i32.const 268435455
    #|              i32.and
    #|              local.set $len
    #|              local.get $len
    #|              i32.const 0
    #|              i32.gt_s
    #|              if
    #|                i32.const 8
    #|                i32.const 2
    #|                i32.shr_u
    #|                local.set $curr_child_offset
    #|                local.get $len
    #|                local.set $remaining_children_count
    #|                br 4
    #|              end
    #|            end
    #|          else
    #|            i32.const 1
    #|            local.get $kind
    #|            i32.eq
    #|            if
    #|            else
    #|              i32.const 3
    #|              local.get $kind
    #|              i32.eq
    #|              if
    #|                local.get $ptr
    #|                call $moonbit.drop_externref
    #|              else
    #|                unreachable
    #|              end
    #|            end
    #|          end
    #|        end
    #|        local.get $ptr
    #|        call $moonbit.free
    #|        local.get $parent
    #|        i32.eqz
    #|        if
    #|          return
    #|        end
    #|        local.get $parent
    #|        i32.load align=1
    #|        local.set $curr_child_offset
    #|        local.get $parent
    #|        i32.load offset=4 align=1
    #|        local.set $remaining_children_count
    #|        local.get $parent
    #|        local.set $ptr
    #|        local.get $ptr
    #|        local.get $curr_child_offset
    #|        i32.const 4
    #|        i32.mul
    #|        i32.add
    #|        i32.load align=1
    #|        local.set $parent
    #|        local.get $curr_child_offset
    #|        i32.const 1
    #|        i32.add
    #|        local.set $curr_child_offset
    #|      end
    #|      loop
    #|        loop
    #|          local.get $remaining_children_count
    #|          i32.const 0
    #|          i32.gt_s
    #|          if
    #|            local.get $remaining_children_count
    #|            i32.const 1
    #|            i32.sub
    #|            local.set $remaining_children_count
    #|            local.get $ptr
    #|            local.get $curr_child_offset
    #|            i32.const 4
    #|            i32.mul
    #|            i32.add
    #|            local.tee $addr_of_next
    #|            i32.load align=1
    #|            local.tee $next
    #|            i32.eqz
    #|            if
    #|              local.get $curr_child_offset
    #|              i32.const 1
    #|              i32.add
    #|              local.set $curr_child_offset
    #|              br 2
    #|            end
    #|            local.get $next
    #|            i32.load align=1
    #|            local.tee $count
    #|            i32.const 1
    #|            i32.gt_s
    #|            if
    #|              local.get $next
    #|              local.get $count
    #|              i32.const 1
    #|              i32.sub
    #|              i32.store align=1
    #|            else
    #|              local.get $count
    #|              i32.const 1
    #|              i32.eq
    #|              if
    #|                local.get $remaining_children_count
    #|                i32.const 0
    #|                i32.eq
    #|                if
    #|                  local.get $ptr
    #|                  call $moonbit.free
    #|                else
    #|                  local.get $ptr
    #|                  local.get $curr_child_offset
    #|                  i32.store align=1
    #|                  local.get $ptr
    #|                  local.get $remaining_children_count
    #|                  i32.store offset=4 align=1
    #|                  local.get $addr_of_next
    #|                  local.get $parent
    #|                  i32.store align=1
    #|                  local.get $ptr
    #|                  local.set $parent
    #|                end
    #|                local.get $next
    #|                local.set $ptr
    #|                br 5
    #|              end
    #|            end
    #|            local.get $curr_child_offset
    #|            i32.const 1
    #|            i32.add
    #|            local.set $curr_child_offset
    #|            br 1
    #|          end
    #|        end
    #|        local.get $ptr
    #|        call $moonbit.free
    #|        local.get $parent
    #|        i32.eqz
    #|        if
    #|          return
    #|        end
    #|        local.get $parent
    #|        i32.load align=1
    #|        local.set $curr_child_offset
    #|        local.get $parent
    #|        i32.load offset=4 align=1
    #|        local.set $remaining_children_count
    #|        local.get $parent
    #|        local.set $ptr
    #|        local.get $ptr
    #|        local.get $curr_child_offset
    #|        i32.const 4
    #|        i32.mul
    #|        i32.add
    #|        i32.load align=1
    #|        local.set $parent
    #|        local.get $curr_child_offset
    #|        i32.const 1
    #|        i32.add
    #|        local.set $curr_child_offset
    #|        br 0
    #|      end
    #|      unreachable
    #|    end)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 3)
  assert_true(locals.length() <= 21, msg=locals.to_string())
  assert_false(
    ssa_test_local_write_indices(instrs).any(fn(idx) { idx > 21U }),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge skips O4z raw pass until self-opt cli flag parsing is safe" {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      "(module (func (local i32) i32.const 1 local.set 0 local.get 0 drop))",
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(
        optimize_level=4,
        shrink_level=1,
        trace=Some(fn(line) { trace.push(line) }),
      ),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected O4z ssa-nomerge skip success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=o4z-ssa-nomerge-noop")
    }),
  )
}

///|
test "ssa-nomerge preserves dropped local increments without local writes" {
  // This fixture has no local writes, so `ssa_nomerge_run` returns before the
  // dropped-increment guard. It protects no-write/raw preservation, not the HOT
  // guard itself.
  let source =
    #|(module
    #|  (func (local i32)
    #|    local.get 0
    #|    i32.const 1
    #|    i32.add
    #|    drop))
    #|)
  let optimized = match pass_test_run_pipeline(source, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected dropped increment ssa-nomerge success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.add"), msg=text)
  assert_true(text.contains("drop"), msg=text)
}

///|
test "ssa-nomerge rewrites functions containing dropped local increment debris" {
  let source =
    #|(module
    #|  (func (local i32)
    #|    i32.const 10
    #|    local.set 0
    #|
    #|    local.get 0
    #|    i32.const 1
    #|    i32.add
    #|    drop
    #|
    #|    local.get 0
    #|    drop))
    #|)
  assert_true(
    ssa_test_hot_path_revision_changed(source),
    msg="expected hot-path rewrite for dropped increment debris",
  )
}

///|
test "ssa-nomerge preserves reaching local after dropped increment debris" {
  let source =
    #|(module
    #|  (func (local i32)
    #|    i32.const 10
    #|    local.set 0
    #|
    #|    local.get 0
    #|    i32.const 1
    #|    i32.add
    #|    drop
    #|
    #|    local.get 0
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dropped increment hot-path success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(10)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ])
}

///|
test "ssa-nomerge handles dropped increment after local.tee" {
  let source =
    #|(module
    #|  (func (local i32)
    #|    i32.const 10
    #|    local.tee 0
    #|    drop
    #|
    #|    local.get 0
    #|    i32.const 1
    #|    i32.add
    #|    drop
    #|
    #|    local.get 0
    #|    drop))
    #|)
  assert_true(
    ssa_test_hot_path_revision_changed(source),
    msg="expected hot-path rewrite after local.tee",
  )
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected dropped increment tee hot-path success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(10)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ])
}

///|
test "ssa-nomerge validates reversed dropped local increment boundary" {
  let source =
    #|(module
    #|  (func (local i32)
    #|    i32.const 10
    #|    local.set 0
    #|
    #|    i32.const 1
    #|    local.get 0
    #|    i32.add
    #|    drop
    #|
    #|    local.get 0
    #|    drop))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.add"), msg=text)
  assert_true(text.contains("drop"), msg=text)
}

///|
test "ssa-nomerge validates non-one dropped increment boundary" {
  let source =
    #|(module
    #|  (func (local i32)
    #|    i32.const 10
    #|    local.set 0
    #|
    #|    local.get 0
    #|    i32.const 2
    #|    i32.add
    #|    drop
    #|
    #|    local.get 0
    #|    drop))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(2)"), msg=text)
  assert_true(text.contains("i32.add"), msg=text)
  assert_true(text.contains("drop"), msg=text)
}

///|
fn ssa_test_hot_path_revision_changed(source : String) -> Bool raise {
  let mod_ = pass_test_module_from_wat(source)
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  @ir.hot_verify_all_or_abort(func)
  let revision_before = @ir.hot_revision_current(func)
  let ctx = HotPassContext::new(
    ssa_nomerge_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected hot-path ssa-nomerge success, got \{err}")
  }
  @ir.hot_revision_current(func) != revision_before
}

///|
fn ssa_test_validate_ssa_nomerge_pipeline(source : String) -> @lib.Module raise {
  let optimized = match pass_test_run_pipeline(source, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ssa-nomerge pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => optimized
    Err(err) =>
      fail(
        "expected ssa-nomerge output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
}

///|
fn ssa_test_module_expected_mutation_valid(
  input : @lib.Module,
  context : String,
) -> @lib.Module raise {
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected \{context} ssa-nomerge success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected \{context} ssa-nomerge output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  assert_true(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg="expected \{context} to mutate; trace:\n\{trace.join("\n")}",
  )
  optimized
}

///|
fn ssa_test_pipeline_expected_mutation_valid(
  source : String,
  context : String,
) -> @lib.Module raise {
  ssa_test_module_expected_mutation_valid(
    pass_test_module_from_wat(source),
    context,
  )
}

///|
fn ssa_test_hot_exceptional_local_traffic_preserved(
  source : String,
) -> Unit raise {
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected exceptional hot-path ssa-nomerge success, got \{err}")
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(
    text.contains("local.set") || text.contains("local.tee"),
    msg=text,
  )
}

///|
fn ssa_test_hot_func_has_local_write(func : @ir.HotFunc) -> Bool {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => return true
      _ => ()
    }
  }
  false
}

///|
fn ssa_test_hot_func_ssa_nomerge_revision_unchanged(
  func : @ir.HotFunc,
) -> Unit raise {
  @ir.hot_verify_all_or_abort(func)
  let revision_before = @ir.hot_revision_current(func)
  let ctx = HotPassContext::new(
    ssa_nomerge_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected hot func ssa-nomerge success, got \{err}")
  }
  @debug.assert_eq(@ir.hot_revision_current(func), revision_before)
}

///|
// Boundary helper for nested CFG shapes outside SSA no-merge v1's straight-line
// value-block/result-if model. These tests must prove the input still contains
// local traffic and that the pass deliberately leaves it untouched; behavior
// gaps that should be implemented must use the expected-mutation helpers instead.
fn ssa_test_unsupported_nested_cfg_pipeline_no_mutation(
  source : String,
) -> Unit raise {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected unsupported nested-CFG ssa-nomerge no-mutation success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
}

///|
fn ssa_test_unsupported_nested_cfg_hot_no_mutation(
  source : String,
) -> Unit raise {
  let mod_ = pass_test_module_from_wat(source)
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  @ir.hot_verify_all_or_abort(func)
  ssa_test_hot_func_ssa_nomerge_revision_unchanged(func)
  assert_true(ssa_test_hot_func_has_local_write(func))
}

///|
fn ssa_test_nested_cfg_hot_local_traffic_preserved(
  source : String,
) -> Unit raise {
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested-CFG hot-path ssa-nomerge success, got \{err}")
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(
    text.contains("local.set") || text.contains("local.tee"),
    msg=text,
  )
  assert_true(text.contains("local.get"), msg=text)
}

///|
// Boundary helper for typed loop-param fixtures with no loop-carried overwrite
// or edge copy requirement. Required typed-loop SSA rewrites use expected-mutation
// helpers elsewhere in this file.
fn ssa_test_no_copy_typed_loop_param_module_no_mutation(
  input : @lib.Module,
) -> Unit raise {
  let trace : Array[String] = []
  match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected no-copy typed-loop-param ssa-nomerge no-mutation success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
}

///|
fn ssa_test_no_copy_typed_loop_param_pipeline_no_mutation(
  source : String,
) -> Unit raise {
  ssa_test_no_copy_typed_loop_param_module_no_mutation(
    pass_test_module_from_wat(source),
  )
}

///|
// Boundary helper for exceptional-control fixtures. SSA no-merge v1 is
// normal-flow-only, so these direct HOT checks assert deliberate no-mutation
// while preserving the local traffic that would be unsafe to rewrite.
fn ssa_test_unsupported_exceptional_hot_no_mutation(
  func : @ir.HotFunc,
) -> Unit raise {
  @ir.hot_verify_all_or_abort(func)
  let revision_before = @ir.hot_revision_current(func)
  let ctx = HotPassContext::new(
    ssa_nomerge_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected hot func ssa-nomerge success, got \{err}")
  }
  @debug.assert_eq(@ir.hot_revision_current(func), revision_before)
  assert_true(ssa_test_hot_func_has_local_write(func))
}

///|
test "ssa-nomerge rewrites no-throw try_table local writes" {
  let input =
    #| (module
    #|   (func (result i32)
    #|     (local i32)
    #|     i32.const 1
    #|     local.set 0
    #|     block
    #|       try_table (catch_all 0)
    #|         i32.const 7
    #|         local.set 0
    #|       end
    #|     end
    #|     i32.const 9
    #|     local.set 0
    #|     local.get 0))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected no-throw try_table ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [@lib.Catch::all(@lib.LabelIdx::new(0U))],
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
}

///|
test "ssa-nomerge does not mutate unsupported exceptional-flow functions" {
  // Exceptional predecessors are outside SSA no-merge v1's normal-flow model;
  // this boundary test must stay green only because the pass leaves them untouched.
  let trace : Array[String] = []
  let source =
    #|(module
    #|  (tag $e)
    #|  (func (export "f") (result i32)
    #|    (local i32)
    #|    i32.const 1
    #|    local.set 0
    #|    (block $h
    #|      (try_table (catch $e $h)
    #|        i32.const 2
    #|        local.set 0
    #|        throw $e))
    #|    local.get 0))
    #|)
  match
    pass_test_run_pipeline(
      source,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected unsupported exceptional-flow ssa-nomerge no-mutation success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge preserves try-table local writes across exceptional exits" {
  let source =
    #|(module
    #|  (tag $e)
    #|  (func (export "f") (result i32)
    #|    (local i32)
    #|    i32.const 1
    #|    local.set 0
    #|    (block $h
    #|      (try_table (catch $e $h)
    #|        i32.const 2
    #|        local.set 0
    #|        throw $e))
    #|    local.get 0))
    #|)
  let optimized = match pass_test_run_pipeline(source, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected try-table ssa-nomerge success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("local.set"), msg=text)
  assert_false(text.contains("drop"), msg=text)
}

///|
test "ssa-nomerge preserves try-table default local at catch continuation" {
  let source =
    #|(module
    #|  (tag $e)
    #|  (func (export "f") (result i32)
    #|    (local i32)
    #|    (block $h
    #|      (try_table (catch $e $h)
    #|        throw $e))
    #|    local.get 0))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(
    text.contains("local.get") || text.contains("i32.const I32(0)"),
    msg=text,
  )
}

///|
test "ssa-nomerge preserves local written before conditional throw to catch" {
  let source =
    #|(module
    #|  (tag $e)
    #|  (func (export "f") (param i32) (result i32)
    #|    (local i32)
    #|    i32.const 10
    #|    local.set 1
    #|    (block $h
    #|      (try_table (catch $e $h)
    #|        local.get 0
    #|        if
    #|          i32.const 20
    #|          local.set 1
    #|          throw $e
    #|        end))
    #|    local.get 1))
    #|)
  ssa_test_hot_exceptional_local_traffic_preserved(source)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("local.set"), msg=text)
}

///|
test "ssa-nomerge preserves legacy rethrow shapes without hot local corruption" {
  let source =
    #|(module
    #|  (tag $e0)
    #|  (func (export "f") (result i32)
    #|    (local i32)
    #|    i32.const 5
    #|    local.set 0
    #|    (try
    #|      (do (throw $e0))
    #|      (catch $e0
    #|        (rethrow 0)))))
    #|)
  ssa_test_hot_exceptional_local_traffic_preserved(source)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("local.set"), msg=text)
}

///|
test "ssa-nomerge preserves delegate shapes without hot local corruption" {
  // Nested legacy delegate WAT does not survive `hot_lift_func`; build HOT IR directly.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let set = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  )
  let block = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let target = @ir.hot_control_node_label(func, block)
  let delegate = @ir.hot_build_delegate(func, target)
  @ir.hot_root_append(func, set)
  @ir.hot_root_append(func, delegate)
  ssa_test_unsupported_exceptional_hot_no_mutation(func)
}

///|
fn ssa_test_expect_scalar_loop_param_branch_proxy(
  source : String,
  min_local_count : Int,
  expect_br_if : Bool,
) -> Unit raise {
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() >= min_local_count, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_branch_proxy(instrs, expect_br_if),
    msg=instrs.to_string(),
  )
}

///|
fn ssa_test_expect_scalar_loop_param_br_if_proxy(
  source : String,
  min_local_count : Int,
) -> Unit raise {
  ssa_test_expect_scalar_loop_param_branch_proxy(source, min_local_count, true)
}

///|
test "ssa-nomerge rewrites direct scalar typed loop-param br backedge" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.tee 1
    #|      local.get 0
    #|      i32.lt_s
    #|      if
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        br $l
    #|      end
    #|    end
    #|    local.get 1))
    #|)
  let optimized = match pass_test_run_pipeline(source, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected scalar loop-param br ssa-nomerge success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites no-copy scalar typed loop-param br_if backedge" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.tee 1
    #|      i32.const 1
    #|      i32.add
    #|      local.get 1
    #|      local.get 0
    #|      i32.lt_s
    #|      br_if $l
    #|      drop
    #|    end
    #|    local.get 1))
    #|)
  let optimized = match pass_test_run_pipeline(source, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected scalar loop-param br_if ssa-nomerge success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_if_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites no-copy scalar typed loop-param br_if for i64" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i64)))
    #|  (func (param i64) (result i64) (local i64)
    #|    i64.const 0
    #|    loop $l (type $loop_t)
    #|      local.tee 1
    #|      i64.const 1
    #|      i64.add
    #|      local.get 1
    #|      local.get 0
    #|      i64.lt_s
    #|      br_if $l
    #|      drop
    #|    end
    #|    local.get 1))
    #|)
  ssa_test_expect_scalar_loop_param_br_if_proxy(source, 2)
}

///|
test "ssa-nomerge rewrites no-copy scalar typed loop-param br_if for f32" {
  let source =
    #|(module
    #|  (type $loop_t (func (param f32)))
    #|  (func (param f32) (result f32) (local f32)
    #|    f32.const 0
    #|    loop $l (type $loop_t)
    #|      local.tee 1
    #|      f32.const 1
    #|      f32.add
    #|      local.get 1
    #|      local.get 0
    #|      f32.lt
    #|      br_if $l
    #|      drop
    #|    end
    #|    local.get 1))
    #|)
  ssa_test_expect_scalar_loop_param_br_if_proxy(source, 2)
}

///|
test "ssa-nomerge rewrites no-copy scalar typed loop-param br_if for f64" {
  let source =
    #|(module
    #|  (type $loop_t (func (param f64)))
    #|  (func (param f64) (result f64) (local f64)
    #|    f64.const 0
    #|    loop $l (type $loop_t)
    #|      local.tee 1
    #|      f64.const 1
    #|      f64.add
    #|      local.get 1
    #|      local.get 0
    #|      f64.lt
    #|      br_if $l
    #|      drop
    #|    end
    #|    local.get 1))
    #|)
  ssa_test_expect_scalar_loop_param_br_if_proxy(source, 2)
}

///|
test "ssa-nomerge rewrites nested no-copy scalar typed loop-param br_if" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.tee 1
    #|      local.get 0
    #|      i32.lt_s
    #|      if
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 1
    #|        i32.const 0
    #|        i32.ge_s
    #|        br_if $l
    #|        drop
    #|      end
    #|    end
    #|    local.get 1))
    #|)
  ssa_test_expect_scalar_loop_param_br_if_proxy(source, 2)
}

///|
test "ssa-nomerge rewrites copy-needing scalar typed loop-param br_if" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.tee 1
    #|      i32.const 1
    #|      i32.add
    #|      local.get 2
    #|      drop
    #|      local.get 1
    #|      i32.const 0
    #|      i32.eq
    #|      if
    #|        i32.const 7
    #|        local.set 2
    #|      else
    #|        i32.const 8
    #|        local.set 2
    #|      end
    #|      local.get 1
    #|      local.get 0
    #|      i32.lt_s
    #|      br_if $l
    #|      drop
    #|      i32.const 9
    #|      local.set 2
    #|    end
    #|    local.get 2))
    #|)
  ssa_test_expect_scalar_loop_param_branch_proxy(source, 3, false)
}

///|
test "ssa-nomerge rewrites nullable reference typed loop-param br_if" {
  let source =
    #|(module
    #|  (type $loop_t (func (param externref)))
    #|  (func (param externref) (param i32) (result externref) (local externref)
    #|    local.get 0
    #|    loop $l (type $loop_t)
    #|      local.set 2
    #|      local.get 2
    #|      local.get 1
    #|      br_if $l
    #|      drop
    #|    end
    #|    local.get 2))
    #|)
  ssa_test_expect_scalar_loop_param_br_if_proxy(source, 2)
}

///|
test "ssa-nomerge rewrites non-null reference typed loop-param br_if" {
  let source =
    #|(module
    #|  (type $loop_t (func (param (ref extern))))
    #|  (func (param (ref extern)) (param i32) (result (ref extern)) (local externref)
    #|    local.get 0
    #|    loop $l (type $loop_t)
    #|      local.set 2
    #|      local.get 2
    #|      ref.as_non_null
    #|      local.get 1
    #|      br_if $l
    #|      drop
    #|    end
    #|    local.get 2
    #|    ref.as_non_null))
    #|)
  ssa_test_expect_scalar_loop_param_br_if_proxy(source, 2)
}

///|
test "ssa-nomerge rewrites copy-needing nullable reference typed loop-param br_if" {
  let source =
    #|(module
    #|  (type $loop_t (func (param externref)))
    #|  (func (param externref) (param i32) (result externref) (local externref externref)
    #|    local.get 0
    #|    loop $l (type $loop_t)
    #|      local.tee 2
    #|      local.get 3
    #|      drop
    #|      local.get 1
    #|      if
    #|        local.get 0
    #|        local.set 3
    #|      else
    #|        ref.null extern
    #|        local.set 3
    #|      end
    #|      local.get 1
    #|      br_if $l
    #|      drop
    #|      ref.null extern
    #|      local.set 3
    #|    end
    #|    local.get 3))
    #|)
  ssa_test_expect_scalar_loop_param_branch_proxy(source, 4, false)
}

///|
test "ssa-nomerge rewrites copy-needing non-null reference typed loop-param br_if" {
  let source =
    #|(module
    #|  (type $loop_t (func (param (ref extern))))
    #|  (func (param (ref extern)) (param i32) (result externref) (local externref externref)
    #|    local.get 0
    #|    loop $l (type $loop_t)
    #|      local.set 2
    #|      local.get 2
    #|      ref.as_non_null
    #|      local.get 3
    #|      drop
    #|      local.get 1
    #|      if
    #|        local.get 0
    #|        local.set 3
    #|      else
    #|        ref.null extern
    #|        local.set 3
    #|      end
    #|      local.get 1
    #|      br_if $l
    #|      drop
    #|      ref.null extern
    #|      local.set 3
    #|    end
    #|    local.get 3))
    #|)
  ssa_test_expect_scalar_loop_param_branch_proxy(source, 4, false)
}

///|
test "ssa-nomerge rewrites no-copy br_on_null typed loop-param backedge" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([extern_ref], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([extern_ref], [extern_ref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([extern_ref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected br_on_null loop-param ssa-nomerge success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_null_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing br_on_null typed loop-param backedge" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([extern_ref], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([extern_ref, @lib.ValType::i32()], [extern_ref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([extern_ref, extern_ref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                  ],
                  Some([
                    @lib.Instruction::ref_null(extern_heap),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected copy-needing br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_null_taken_copy_branch(instrs, 3U),
    msg=instrs.to_string(),
  )
  assert_true(
    instrs.to_string().contains("ref.as_non_null"),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites multi-result br_on_null taken-edge copies" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([extern_ref, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), extern_ref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(7),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(8),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::i32_const(42),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(9),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::i32_const(1),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::i32_add(),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected multi-result br_on_null ssa-nomerge success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_null_taken_copy_branch(instrs, 2U),
    msg=instrs.to_string(),
  )
  assert_true(
    instrs.to_string().contains("ref.as_non_null"),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites multi-param typed loop direct br backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i64)))
    #|  (func (param i32) (result i32) (local i32 i64)
    #|    i32.const 0
    #|    i64.const 1
    #|    loop $l (type $loop_t)
    #|      local.set 2
    #|      local.tee 1
    #|      local.get 0
    #|      i32.lt_s
    #|      if
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 2
    #|        i64.const 1
    #|        i64.add
    #|        br $l
    #|      end
    #|    end
    #|    local.get 1))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites multi-param typed loop br_if backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i64)))
    #|  (func (param i32) (result i32) (local i32 i64)
    #|    i32.const 0
    #|    i64.const 1
    #|    loop $l (type $loop_t)
    #|      local.set 2
    #|      local.set 1
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.get 2
    #|      i64.const 1
    #|      i64.add
    #|      local.get 1
    #|      local.get 0
    #|      i32.lt_s
    #|      br_if $l
    #|      drop
    #|      drop
    #|    end
    #|    local.get 1))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites scalar typed loop br_table backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.set 1
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.get 0
    #|      br_table $l $l
    #|    end
    #|    local.get 1))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_br_table_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing scalar typed loop br_table backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.set 1
    #|      local.get 2
    #|      drop
    #|      local.get 1
    #|      i32.const 0
    #|      i32.eq
    #|      if
    #|        i32.const 7
    #|        local.set 2
    #|      else
    #|        i32.const 8
    #|        local.set 2
    #|      end
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.get 0
    #|      br_table $l $l
    #|    end
    #|    local.get 2))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_br_table_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites multi-param typed loop br_table backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i64)))
    #|  (func (param i32) (result i32) (local i32 i64)
    #|    i32.const 0
    #|    i64.const 1
    #|    loop $l (type $loop_t)
    #|      local.set 2
    #|      local.set 1
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.get 2
    #|      i64.const 1
    #|      i64.add
    #|      local.get 0
    #|      br_table $l $l
    #|    end
    #|    local.get 1))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites mixed-target single-result typed loop br_table backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    block $exit (result i32)
    #|      i32.const 0
    #|      loop $l (type $loop_t)
    #|        local.tee 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 0
    #|        br_table $l $exit
    #|      end
    #|    end)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(instrs.to_string().contains("i32.eq"), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites mixed-target single-param no-result typed loop br_table backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    block $exit (result i32)
    #|      i32.const 0
    #|      loop $l (type $loop_t)
    #|        local.tee 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 0
    #|        br_table $l $exit
    #|      end
    #|      unreachable
    #|    end)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_true(instrs.to_string().contains("i32.eq"), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites copy-needing mixed-target single-param no-result typed loop br_table backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    block $exit (result i32)
    #|      i32.const 0
    #|      loop $l (type $loop_t)
    #|        local.set 1
    #|        local.get 2
    #|        drop
    #|        local.get 1
    #|        i32.const 0
    #|        i32.eq
    #|        if
    #|          i32.const 7
    #|          local.set 2
    #|        else
    #|          i32.const 8
    #|          local.set 2
    #|        end
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 0
    #|        br_table $l $exit
    #|      end
    #|      unreachable
    #|    end)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_true(instrs.to_string().contains("i32.eq"), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites mixed-target multi-param typed loop br_table backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i64)))
    #|  (type $exit_t (func (result i32 i64)))
    #|  (func (param i32) (result i32 i64) (local i32 i64)
    #|    block $exit (type $exit_t)
    #|      i32.const 0
    #|      i64.const 1
    #|      loop $l (type $loop_t)
    #|        local.set 2
    #|        local.set 1
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 2
    #|        i64.const 1
    #|        i64.add
    #|        local.get 0
    #|        br_table $l $exit
    #|      end
    #|      unreachable
    #|    end)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(instrs.to_string().contains("i32.eq"), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites copy-needing mixed-target single-result typed loop br_table backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    block $exit (result i32)
    #|      i32.const 0
    #|      loop $l (type $loop_t)
    #|        local.set 1
    #|        local.get 1
    #|        i32.const 0
    #|        i32.eq
    #|        if
    #|          i32.const 7
    #|          local.set 2
    #|        else
    #|          i32.const 8
    #|          local.set 2
    #|        end
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 0
    #|        br_table $l $exit
    #|      end
    #|    end)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(instrs.to_string().contains("i32.eq"), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites single-result typed loop direct br backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.tee 1
    #|      local.get 0
    #|      i32.lt_s
    #|      if
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        br $l
    #|      end
    #|      local.get 1
    #|    end)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites single-result typed loop br_if backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.set 1
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.get 1
    #|      local.get 0
    #|      i32.lt_s
    #|      br_if $l
    #|      drop
    #|      local.get 1
    #|    end)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites multi-param single-result typed loop br_table backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i64) (result i32)))
    #|  (func (param i32) (result i32) (local i32 i64)
    #|    i32.const 0
    #|    i64.const 1
    #|    loop $l (type $loop_t)
    #|      local.set 2
    #|      local.set 1
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.get 2
    #|      i64.const 1
    #|      i64.add
    #|      local.get 0
    #|      br_table $l $l
    #|    end)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites multi-param typed loop br_on_null backedges" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), extern_ref], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([extern_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), extern_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected multi-param br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing multi-param typed loop br_on_null backedges" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), extern_ref], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([extern_ref, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), extern_ref, extern_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
                  ],
                  Some([
                    @lib.Instruction::ref_null(extern_heap),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected copy-needing multi-param br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 3, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_ref_null_branch_copy_lowering(instrs, 4U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing multi-param single-result typed loop br_on_null backedges" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), extern_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([extern_ref, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), extern_ref, extern_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
                  ],
                  Some([
                    @lib.Instruction::ref_null(extern_heap),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected copy-needing multi-param single-result br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 3, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_ref_null_branch_copy_lowering(instrs, 4U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites multi-param typed loop br_on_non_null backedges" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let non_null_extern_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, extern_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), non_null_extern_ref], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([non_null_extern_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), extern_ref, extern_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected multi-param br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 3, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing multi-param typed loop br_on_non_null backedges" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let non_null_extern_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, extern_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), non_null_extern_ref], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([non_null_extern_ref, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([
            @lib.ValType::i32(),
            extern_ref,
            extern_ref,
            extern_ref,
          ]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
                  ],
                  Some([
                    @lib.Instruction::ref_null(extern_heap),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected copy-needing multi-param br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 4, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_ref_non_null_branch_copy_lowering(instrs, 4U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing multi-param single-result typed loop br_on_non_null backedges" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let non_null_extern_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, extern_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), non_null_extern_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([non_null_extern_ref, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([
            @lib.ValType::i32(),
            extern_ref,
            extern_ref,
            extern_ref,
          ]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
                  ],
                  Some([
                    @lib.Instruction::ref_null(extern_heap),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(extern_heap),
                @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected copy-needing multi-param single-result br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 4, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_ref_non_null_branch_copy_lowering(instrs, 4U),
    msg=instrs.to_string(),
  )
}

///|
fn ssa_test_multi_param_loop_store_local_tee_ref_branch_module(
  non_null_branch : Bool,
  single_result : Bool,
) -> @lib.Module {
  let struct_idx = @lib.TypeIdx::new(0U)
  let struct_heap = @lib.HeapType::new(struct_idx)
  let nullable_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, struct_heap),
  )
  let non_null_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, struct_heap),
  )
  let loop_ref_type = if non_null_branch {
    non_null_struct_ref
  } else {
    nullable_struct_ref
  }
  let loop_result_types = if single_result { [@lib.ValType::i32()] } else { [] }
  let loop_body : Array[@lib.Instruction] = [
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::i32_add(),
  ]
  if !non_null_branch {
    loop_body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(2U)))
  }
  loop_body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(3U)),
  ])
  if non_null_branch {
    loop_body.push(@lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)))
    if !single_result {
      loop_body.push(@lib.Instruction::drop())
    }
  } else {
    loop_body.push(@lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)))
    loop_body.push(@lib.Instruction::drop())
    loop_body.push(@lib.Instruction::drop())
    if !single_result {
      loop_body.push(@lib.Instruction::drop())
    }
  }
  let func_body : Array[@lib.Instruction] = [@lib.Instruction::i32_const(0)]
  if non_null_branch {
    func_body.push(@lib.Instruction::struct_new_default(struct_idx))
  } else {
    func_body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  }
  func_body.push(
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
      @lib.Expr::new(loop_body),
    ),
  )
  if !single_result {
    func_body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func(
            [@lib.ValType::i32(), loop_ref_type],
            loop_result_types,
          ),
        ),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([nullable_struct_ref], [@lib.ValType::i32()]),
        ),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([
          @lib.ValType::i32(),
          nullable_struct_ref,
          nullable_struct_ref,
        ]),
        @lib.Expr::new(func_body),
      ),
    ]),
  )
}

///|
test "ssa-nomerge rewrites ref-null-tested multi-param typed loop br_on_null backedges" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), extern_ref], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([extern_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), extern_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::ref_null_type(
                  @lib.RefType::new(true, extern_heap),
                ),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref-null-tested br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites ref-null-tested multi-param typed loop br_on_non_null backedges" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let non_null_extern_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, extern_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), non_null_extern_ref], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([non_null_extern_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
                @lib.Instruction::ref_null_type(
                  @lib.RefType::new(true, extern_heap),
                ),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref-null-tested br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites any-convert-tested multi-param typed loop br_on_null backedges" {
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::anyref()], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::externref()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::anyref()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::any_convert_extern(),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::any_convert_extern(),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected any-convert-tested br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites extern-convert-tested multi-param typed loop br_on_null backedges" {
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::i32(), @lib.ValType::externref()],
              [],
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::anyref()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([
            @lib.ValType::i32(),
            @lib.ValType::externref(),
          ]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::extern_convert_any(),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::extern_convert_any(),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected extern-convert-tested br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites ref-cast-tested multi-param typed loop br_on_null backedges" {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let any_ref = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), any_ref], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([any_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_cast(true, any_heap),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref-cast-tested br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites ref-cast-tested multi-param typed loop br_on_non_null backedges" {
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i31ref()], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_i31(),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_null_type(
                  @lib.RefType::new(true, i31_heap),
                ),
                @lib.Instruction::ref_cast(true, i31_heap),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref-cast-tested br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites ref-i31-tested multi-param typed loop br_on_null backedges" {
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::i32(), @lib.ValType::i31ref_nullable()],
              [@lib.ValType::i32()],
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_i31(),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
                @lib.Instruction::ref_null_type(
                  @lib.RefType::new(
                    true,
                    @lib.HeapType::abs(@lib.AbsHeapType::i31()),
                  ),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_i31(),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref-i31-tested br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites ref-i31-tested multi-param typed loop br_on_non_null backedges" {
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i31ref()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_i31(),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_i31(),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref-i31-tested br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites ref-func-tested multi-param typed loop br_on_null concrete-label backedges" {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let loop_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let callee_heap = @lib.HeapType::new(callee_type_idx)
  let nullable_callee_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, callee_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), nullable_callee_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx, callee_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), nullable_callee_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_null(callee_heap),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(loop_type_idx),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
          ]),
        ),
        @lib.Func::new(@lib.Locals::new([]), @lib.Expr::new([])),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref-func-tested br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites ref-func-tested multi-param typed loop br_on_non_null concrete-label backedges" {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let loop_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let callee_heap = @lib.HeapType::new(callee_type_idx)
  let nullable_callee_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, callee_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), nullable_callee_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx, callee_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), nullable_callee_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_null(callee_heap),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(loop_type_idx),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
          ]),
        ),
        @lib.Func::new(@lib.Locals::new([]), @lib.Expr::new([])),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref-func-tested br_on_non_null concrete-label loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites ref-func-tested multi-param typed loop br_on_non_null funcref-label backedges" {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let loop_type_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let funcref = @lib.ValType::funcref()
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), funcref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx, callee_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), funcref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_null_type(
              @lib.RefType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(loop_type_idx),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
          ]),
        ),
        @lib.Func::new(@lib.Locals::new([]), @lib.Expr::new([])),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref-func-tested br_on_non_null funcref-label loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites struct-subtype-new-default-tested multi-param typed loop br_on_non_null parent-label backedges" {
  let base_idx = @lib.TypeIdx::new(0U)
  let child_idx = @lib.TypeIdx::new(1U)
  let loop_type_idx = @lib.TypeIdx::new(2U)
  let test_type_idx = @lib.TypeIdx::new(3U)
  let base_heap = @lib.HeapType::new(base_idx)
  let nullable_base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, base_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::new(false, [base_idx], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), nullable_base_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_null(base_heap),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(loop_type_idx),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::struct_new_default(child_idx),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected struct-subtype-new-default-tested br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites array-subtype-new-default-tested multi-param typed loop br_on_non_null parent-label backedges" {
  let base_idx = @lib.TypeIdx::new(0U)
  let child_idx = @lib.TypeIdx::new(1U)
  let loop_type_idx = @lib.TypeIdx::new(2U)
  let test_type_idx = @lib.TypeIdx::new(3U)
  let base_heap = @lib.HeapType::new(base_idx)
  let nullable_base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, base_heap),
  )
  let array_field = @lib.FieldType::new(
    @lib.StorageType::val_type(@lib.ValType::i32()),
    @lib.Mut::var_(),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::array(array_field)),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [base_idx],
            @lib.CompType::array(array_field),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), nullable_base_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_null(base_heap),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(loop_type_idx),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::array_new_default(child_idx),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected array-subtype-new-default-tested br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites ref-func-subtype-tested multi-param typed loop br_on_non_null parent-label backedges" {
  let base_idx = @lib.TypeIdx::new(0U)
  let child_idx = @lib.TypeIdx::new(1U)
  let loop_type_idx = @lib.TypeIdx::new(2U)
  let test_type_idx = @lib.TypeIdx::new(3U)
  let base_heap = @lib.HeapType::new(base_idx)
  let nullable_base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, base_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::new(false, [base_idx], @lib.CompType::func([], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), nullable_base_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx, child_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_null(base_heap),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(loop_type_idx),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
          ]),
        ),
        @lib.Func::new(@lib.Locals::new([]), @lib.Expr::new([])),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref-func-subtype-tested br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites struct-new-default-tested multi-param typed loop br_on_null backedges" {
  let struct_idx = @lib.TypeIdx::new(0U)
  let struct_heap = @lib.HeapType::new(struct_idx)
  let nullable_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, struct_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), nullable_struct_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), nullable_struct_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_null(struct_heap),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::struct_new_default(struct_idx),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected struct-new-default-tested br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites array-new-default-tested multi-param typed loop br_on_null backedges" {
  let array_idx = @lib.TypeIdx::new(0U)
  let array_heap = @lib.HeapType::new(array_idx)
  let nullable_array_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, array_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), nullable_array_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), nullable_array_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_null(array_heap),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32::new(0)),
                @lib.Instruction::array_new_default(array_idx),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected array-new-default-tested br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites struct-new-default-tested multi-param typed loop br_on_non_null nullable-label backedges" {
  let struct_idx = @lib.TypeIdx::new(0U)
  let struct_heap = @lib.HeapType::new(struct_idx)
  let nullable_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, struct_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), nullable_struct_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_null(struct_heap),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::struct_new_default(struct_idx),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected struct-new-default-tested br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites array-new-default-tested multi-param typed loop br_on_non_null nullable-label backedges" {
  let array_idx = @lib.TypeIdx::new(0U)
  let array_heap = @lib.HeapType::new(array_idx)
  let nullable_array_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, array_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), nullable_array_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::ref_null(array_heap),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::array_new_default(array_idx),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected array-new-default-tested br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites local-tee-tested multi-param typed loop br_on_null backedges" {
  let input = ssa_test_multi_param_loop_store_local_tee_ref_branch_module(
    false, false,
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected local-tee-tested multi-param br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 3, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites local-tee-tested multi-param single-result typed loop br_on_null backedges" {
  let input = ssa_test_multi_param_loop_store_local_tee_ref_branch_module(
    false, true,
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected local-tee-tested multi-param single-result br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 3, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites local-tee-tested multi-param typed loop br_on_non_null backedges" {
  let input = ssa_test_multi_param_loop_store_local_tee_ref_branch_module(
    true, false,
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected local-tee-tested multi-param br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 3, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites local-tee-tested multi-param single-result typed loop br_on_non_null backedges" {
  let input = ssa_test_multi_param_loop_store_local_tee_ref_branch_module(
    true, true,
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected local-tee-tested multi-param single-result br_on_non_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 3, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites multi-param single-result typed loop br_on_null backedges" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), extern_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([extern_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), extern_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected multi-param single-result br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested-loop multi-param typed loop br backedges" {
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i64()], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i64()], []),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i64()]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::loop_(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::i32_const(@lib.I32::new(1)),
                    @lib.Instruction::i32_add(),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                    @lib.Instruction::i64_const(@lib.I64::new(1L)),
                    @lib.Instruction::i64_add(),
                    @lib.Instruction::br(@lib.LabelIdx::new(1U)),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested-loop multi-param br loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested-loop multi-param single-result typed loop br_if backedges" {
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i64()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i64()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i64()]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::loop_(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::i32_const(@lib.I32::new(1)),
                    @lib.Instruction::i32_add(),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                    @lib.Instruction::i64_const(@lib.I64::new(1L)),
                    @lib.Instruction::i64_add(),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::i32_const(@lib.I32::new(10)),
                    @lib.Instruction::i32_lt_s(),
                    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::unreachable_(),
                  ]),
                ),
                @lib.Instruction::unreachable_(),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested-loop multi-param single-result br_if loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested-loop multi-param typed loop br_on_null backedges" {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let any_ref = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), any_ref], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([any_ref], [])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), any_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::loop_(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                    @lib.Instruction::i32_const(@lib.I32::new(1)),
                    @lib.Instruction::i32_add(),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br_on_null(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::drop(),
                    @lib.Instruction::drop(),
                    @lib.Instruction::drop(),
                    @lib.Instruction::unreachable_(),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested-loop multi-param br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested self-loop br_if plus multi-param typed loop br backedges" {
  let source =
    #|(module
    #|  (type $outer_t (func (param i32 i64)))
    #|  (func (param i32 i64) (result i32) (local i32 i64)
    #|    local.get 0
    #|    local.get 1
    #|    loop $outer (type $outer_t)
    #|      local.set 3
    #|      local.set 2
    #|      loop $inner
    #|        local.get 2
    #|        i32.const 0
    #|        i32.gt_s
    #|        br_if $inner
    #|        local.get 2
    #|        i32.const 1
    #|        i32.add
    #|        local.get 3
    #|        i64.const 1
    #|        i64.add
    #|        br $outer
    #|      end
    #|    end
    #|    local.get 2)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested self-loop br_if plus single-result typed loop br_if backedges" {
  let source =
    #|(module
    #|  (type $outer_t (func (param i32 i64) (result i32)))
    #|  (func (param i32 i64) (result i32) (local i32 i64)
    #|    local.get 0
    #|    local.get 1
    #|    loop $outer (type $outer_t)
    #|      local.set 3
    #|      local.set 2
    #|      loop $inner
    #|        local.get 2
    #|        i32.const 0
    #|        i32.gt_s
    #|        br_if $inner
    #|        local.get 2
    #|        i32.const 1
    #|        i32.add
    #|        local.get 3
    #|        i64.const 1
    #|        i64.add
    #|        local.get 2
    #|        i32.const 10
    #|        i32.lt_s
    #|        br_if $outer
    #|        unreachable
    #|      end
    #|      unreachable
    #|    end)
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested self-loop br_if plus typed loop br_on_null backedges" {
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let extern_ref = @lib.ValType::ref_type(@lib.RefType::new(true, extern_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), extern_ref], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([extern_ref], [])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), extern_ref]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(0)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::loop_(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                    @lib.Instruction::i32_const(@lib.I32::new(0)),
                    @lib.Instruction::i32_gt_s(),
                    @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                    @lib.Instruction::i32_const(@lib.I32::new(1)),
                    @lib.Instruction::i32_add(),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br_on_null(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::drop(),
                    @lib.Instruction::drop(),
                    @lib.Instruction::drop(),
                    @lib.Instruction::unreachable_(),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested self-loop br_if plus br_on_null loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
fn ssa_test_multi_param_loop_store_cast_module(
  fail_variant : Bool,
  copy_needed : Bool,
  single_result : Bool,
) -> @lib.Module {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref_type = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let i31_ref_type = @lib.ValType::ref_type(@lib.RefType::new(false, i31_heap))
  let nullable_i31_ref_type = @lib.ValType::ref_type(
    @lib.RefType::new(true, i31_heap),
  )
  let loop_ref_type = if fail_variant { any_ref_type } else { i31_ref_type }
  let stored_ref_type = if fail_variant {
    any_ref_type
  } else {
    nullable_i31_ref_type
  }
  let loop_result_types = if single_result { [@lib.ValType::i32()] } else { [] }
  let loop_body : Array[@lib.Instruction] = [
    @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
  ]
  if copy_needed {
    loop_body.append([
      @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::if_(
        @lib.BlockType::void_(),
        [
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
        ],
        Some([
          @lib.Instruction::ref_null(any_heap),
          @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
        ]),
      ),
    ])
  }
  loop_body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::i32_add(),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(
      if fail_variant {
        @lib.LocalIdx::new(3U)
      } else {
        @lib.LocalIdx::new(0U)
      },
    ),
  ])
  if fail_variant {
    loop_body.push(
      @lib.Instruction::br_on_cast_fail(
        @lib.LabelIdx::new(0U),
        true,
        any_heap,
        false,
        i31_heap,
      ),
    )
  } else {
    loop_body.push(
      @lib.Instruction::br_on_cast(
        @lib.LabelIdx::new(0U),
        true,
        any_heap,
        false,
        i31_heap,
      ),
    )
  }
  loop_body.append([@lib.Instruction::drop(), @lib.Instruction::drop()])
  if copy_needed {
    loop_body.append([
      @lib.Instruction::ref_null(any_heap),
      @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
    ])
  }
  if single_result {
    loop_body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(2U)))
  }
  let func_body : Array[@lib.Instruction] = [
    @lib.Instruction::i32_const(@lib.I32::new(0)),
  ]
  if fail_variant {
    func_body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  } else {
    func_body.push(@lib.Instruction::i32_const(@lib.I32::new(1)))
    func_body.push(@lib.Instruction::ref_i31())
  }
  func_body.push(
    @lib.Instruction::loop_(
      @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
      @lib.Expr::new(loop_body),
    ),
  )
  if !single_result {
    func_body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(2U)))
  }
  let local_types = if copy_needed {
    [@lib.ValType::i32(), stored_ref_type, any_ref_type]
  } else {
    [@lib.ValType::i32(), stored_ref_type]
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func(
            [@lib.ValType::i32(), loop_ref_type],
            loop_result_types,
          ),
        ),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([any_ref_type, @lib.ValType::i32()], [
            @lib.ValType::i32(),
          ]),
        ),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types(local_types),
        @lib.Expr::new(func_body),
      ),
    ]),
  )
}

///|
test "ssa-nomerge rewrites multi-param typed loop br_on_cast backedges" {
  let input = ssa_test_multi_param_loop_store_cast_module(false, false, false)
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected multi-param br_on_cast loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing multi-param typed loop br_on_cast backedges" {
  let input = ssa_test_multi_param_loop_store_cast_module(false, true, false)
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected copy-needing multi-param br_on_cast loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 3, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 4U, true),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing multi-param single-result typed loop br_on_cast backedges" {
  let input = ssa_test_multi_param_loop_store_cast_module(false, true, true)
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected copy-needing multi-param single-result br_on_cast loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 3, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 4U, true),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing multi-param typed loop br_on_cast_fail backedges" {
  let input = ssa_test_multi_param_loop_store_cast_module(true, true, false)
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected copy-needing multi-param br_on_cast_fail loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 3, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 4U, false),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing multi-param single-result typed loop br_on_cast_fail backedges" {
  let input = ssa_test_multi_param_loop_store_cast_module(true, true, true)
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected copy-needing multi-param single-result br_on_cast_fail loop-param ssa-nomerge success, got \{err}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 3, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 4U, false),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites no-throw try_table scalar proxy backedges" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    (block $h
    #|      i32.const 0
    #|      (loop $l (param i32)
    #|        local.set 1
    #|        (try_table (catch_all $h)
    #|          local.get 1
    #|          i32.const 1
    #|          i32.add
    #|          br $l)))
    #|    local.get 1))
    #|)
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    source, "no-throw try_table scalar proxy backedge",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites no-throw try_table multi-param typed loop br backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    (block $h
    #|      i32.const 0
    #|      local.get 0
    #|      (loop $l (type $loop_t)
    #|        local.set 2
    #|        local.set 1
    #|        (try_table (catch_all $h)
    #|          local.get 1
    #|          i32.const 1
    #|          i32.add
    #|          local.get 2
    #|          br $l)))
    #|    local.get 1))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites no-throw try_table single-result typed loop br backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    i32.const 0
    #|    local.get 0
    #|    (loop $l (type $loop_t)
    #|      local.set 2
    #|      local.set 1
    #|      (block $h
    #|        (try_table (catch_all $h)
    #|          local.get 1
    #|          i32.const 1
    #|          i32.add
    #|          local.get 2
    #|          br $l))
    #|      unreachable)))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites throwing try_table typed loop backedges" {
  let source =
    #|(module
    #|  (tag $e)
    #|  (func (param i32) (result i32) (local i32)
    #|    (block $h
    #|      i32.const 0
    #|      (loop $l (param i32)
    #|        local.set 1
    #|        (try_table (catch $e $h)
    #|          local.get 1
    #|          i32.const 1
    #|          i32.add
    #|          br $l
    #|          throw $e)))
    #|    local.get 1))
    #|)
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    source, "throwing try_table typed-loop backedge",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites multi-result typed loop-param direct br" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32) (result i32 i64)))
    #|  (func (param i32) (result i32 i64) (local i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.tee 1
    #|      local.get 0
    #|      i32.lt_s
    #|      if
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        br $l
    #|      end
    #|      local.get 1
    #|      i64.const 7
    #|    end)
    #|)
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    source, "multi-result typed loop-param direct br",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites multi-instruction br_on_null loop-store tested refs" {
  let externref = @lib.ValType::externref()
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::block(
                  @lib.BlockType::val_type(externref),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                  ]),
                ),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "multi-instruction br_on_null loop-store tested ref",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites multi-instruction br_on_non_null loop-store tested refs" {
  let externref = @lib.ValType::externref()
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([externref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::block(
                  @lib.BlockType::val_type(externref),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                  ]),
                ),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "multi-instruction br_on_non_null loop-store tested ref",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites non-current multi-instruction br_on_null branch inputs" {
  let externref = @lib.ValType::externref()
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([externref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ],
              Some([
                @lib.Instruction::i32_const(8),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::block(
                  @lib.BlockType::val_type(externref),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                  ]),
                ),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(9),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "non-current multi-instruction br_on_null branch input",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites non-current multi-instruction br_on_non_null branch inputs" {
  let externref = @lib.ValType::externref()
  let extern_heap = @lib.HeapType::abs(@lib.AbsHeapType::extern_())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([externref], [externref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32()]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::i32_const(7),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ],
              Some([
                @lib.Instruction::i32_const(8),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::block(
              @lib.BlockType::val_type(externref),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::val_type(externref),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                  ]),
                ),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_null(extern_heap),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "non-current multi-instruction br_on_non_null branch input",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites non-current scalar typed loop br_table targets" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.set 1
    #|      block $inner
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 0
    #|        br_table $l $l
    #|      end
    #|      local.get 1
    #|      drop
    #|    end
    #|    local.get 1))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_br_table_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites try_table scalar proxy br_if catch-relabeling" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    (block $h
    #|      i32.const 0
    #|      (loop $l (param i32)
    #|        local.set 1
    #|        (try_table (catch_all $h)
    #|          local.get 1
    #|          i32.const 1
    #|          i32.add
    #|          local.get 0
    #|          br_if $l
    #|          drop)))
    #|    local.get 1))
    #|)
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    source, "try_table scalar proxy br_if catch-label relabeling",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_if_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites try_table single-result fallthrough store model" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    (block $h
    #|      i32.const 0
    #|      local.get 0
    #|      loop $l (type $loop_t)
    #|        local.set 2
    #|        local.set 1
    #|        try_table (result i32) (catch_all $h)
    #|          local.get 1
    #|          i32.const 1
    #|          i32.add
    #|          local.get 2
    #|          local.get 0
    #|          br_if $l
    #|          drop
    #|        end
    #|      end
    #|      return)
    #|    local.get 1))
    #|)
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    source, "try_table single-result fallthrough store model",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested non-void loop self-backedges" {
  let source =
    #|(module
    #|  (type $outer_t (func (param i32)))
    #|  (type $inner_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    i32.const 0
    #|    loop $outer (type $outer_t)
    #|      local.set 1
    #|      i32.const 0
    #|      loop $inner (type $inner_t)
    #|        local.set 2
    #|        local.get 2
    #|        i32.const 1
    #|        i32.add
    #|        local.get 0
    #|        br_if $inner
    #|        drop
    #|      end
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      br $outer
    #|    end
    #|    local.get 1))
    #|)
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    source, "nested non-void loop self-backedge",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_if_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested other-label branches under typed loop params" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $outer (type $loop_t)
    #|      local.set 1
    #|      block $other
    #|        br $other
    #|      end
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      br $outer
    #|    end
    #|    local.get 1))
    #|)
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    source, "nested other-label branch under typed loop param",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing non-current scalar typed loop br_table targets" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.set 1
    #|      local.get 2
    #|      drop
    #|      local.get 1
    #|      i32.const 0
    #|      i32.eq
    #|      if
    #|        i32.const 7
    #|        local.set 2
    #|      else
    #|        i32.const 8
    #|        local.set 2
    #|      end
    #|      block $inner
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 0
    #|        br_table $l $l
    #|      end
    #|    end
    #|    local.get 2))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_br_table_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites non-current multi-param typed loop br_table targets" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    i32.const 0
    #|    local.get 0
    #|    loop $l (type $loop_t)
    #|      local.set 2
    #|      local.set 1
    #|      block $inner
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 2
    #|        local.get 0
    #|        br_table $l $l
    #|      end
    #|    end
    #|    local.get 1))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites non-current single-result typed loop br_table targets" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    i32.const 0
    #|    local.get 0
    #|    loop $l (type $loop_t)
    #|      local.set 2
    #|      local.set 1
    #|      block $inner
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 2
    #|        local.get 0
    #|        br_table $l $l
    #|      end
    #|      local.get 1
    #|    end))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites non-current mixed-target scalar typed loop br_table targets" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    block $exit (result i32)
    #|      i32.const 0
    #|      loop $l (type $loop_t)
    #|        local.set 1
    #|        block $inner
    #|          local.get 1
    #|          i32.const 1
    #|          i32.add
    #|          local.get 0
    #|          br_table $l $exit
    #|        end
    #|        unreachable
    #|      end
    #|      unreachable
    #|    end))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_true(instrs.to_string().contains("i32.eq"), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites non-current mixed-target multi-param typed loop br_table targets" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32 i64)))
    #|  (type $exit_t (func (result i32 i64)))
    #|  (func (param i32) (result i32 i64) (local i32 i64)
    #|    block $exit (type $exit_t)
    #|      i32.const 0
    #|      i64.const 1
    #|      loop $l (type $loop_t)
    #|        local.set 2
    #|        local.set 1
    #|        block $inner
    #|          local.get 1
    #|          i32.const 1
    #|          i32.add
    #|          local.get 2
    #|          i64.const 1
    #|          i64.add
    #|          local.get 0
    #|          br_table $l $exit
    #|        end
    #|        unreachable
    #|      end
    #|      unreachable
    #|    end))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_multi_param_loop_store_backedge(instrs),
    msg=instrs.to_string(),
  )
  assert_true(instrs.to_string().contains("i32.eq"), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites mixed scalar typed loop br_table and br_if backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.set 1
    #|      local.get 1
    #|      i32.const 3
    #|      i32.lt_s
    #|      if
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.get 0
    #|        br_table $l $l
    #|      end
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.get 1
    #|      local.get 0
    #|      i32.lt_s
    #|      br_if $l
    #|      drop
    #|    end
    #|    local.get 1))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_br_table_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_if_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites concrete reference typed loop br_table backedges" {
  let struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([struct_ref], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([struct_ref, @lib.ValType::i32()], [struct_ref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([struct_ref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::br_table(
                  [@lib.LabelIdx::new(0U)],
                  @lib.LabelIdx::new(0U),
                ),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected reference typed-loop br_table success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_br_table_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites mixed scalar typed loop br and br_if backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.set 1
    #|      local.get 1
    #|      i32.const 3
    #|      i32.lt_s
    #|      if
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        br $l
    #|      end
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.get 1
    #|      local.get 0
    #|      i32.lt_s
    #|      br_if $l
    #|      drop
    #|    end
    #|    local.get 1))
    #|)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_if_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites mixed reference typed loop br_if and br_on_null backedges" {
  let struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([struct_ref], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([struct_ref, @lib.ValType::i32()], [struct_ref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([struct_ref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected mixed reference typed-loop success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_if_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_loop_param_null_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites nested mixed reference typed loop br_if and br_on_null backedges" {
  let struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([struct_ref], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([struct_ref, @lib.ValType::i32()], [struct_ref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([struct_ref]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                    @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
                    @lib.Instruction::drop(),
                  ],
                  None,
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::drop(),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested mixed reference typed-loop success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected output to validate, got \{@validate.validation_error_message(err)}",
      )
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_if_proxy(instrs),
    msg=instrs.to_string(),
  )
  assert_true(
    ssa_test_instrs_have_loop_param_null_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge does not mutate branch-bearing nested loops without loop-carried backedges" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $outer (type $loop_t)
    #|      local.set 1
    #|      loop $inner
    #|        br $inner
    #|      end
    #|    end
    #|    local.get 1))
    #|)
  // Boundary coverage: this fixture has branch-bearing nested control but no
  // backedge carrying a new value to the typed outer loop, so ssa-nomerge has
  // no required no-merge rewrite to perform.
  ssa_test_no_copy_typed_loop_param_pipeline_no_mutation(source)
}

///|
test "ssa-nomerge rewrites typed loop-param control functions" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    (local.get 0)
    #|    (loop $l (type $loop_t)
    #|      local.tee 1
    #|      local.get 0
    #|      i32.lt_s
    #|      if (result i32)
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        br $l
    #|      else
    #|        local.get 1
    #|      end)))
    #|)
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    source, "typed loop-param control function",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites locals written before typed loop-param control" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    i32.const 5
    #|    local.set 1
    #|    local.get 0
    #|    (loop $l (type $loop_t)
    #|      local.tee 2
    #|      local.get 0
    #|      i32.lt_s
    #|      if (result i32)
    #|        local.get 2
    #|        i32.const 1
    #|        i32.add
    #|        br $l
    #|      else
    #|        local.get 1
    #|      end)))
    #|)
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    source, "locals before typed loop-param control",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(text.contains("i32.const I32(5)"), msg=text)
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites typed loop-param backedge values separate from body locals" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    i32.const 100
    #|    local.set 1
    #|    local.get 0
    #|    (loop $l (type $loop_t)
    #|      local.tee 2
    #|      local.get 0
    #|      i32.lt_s
    #|      if (result i32)
    #|        local.get 2
    #|        i32.const 1
    #|        i32.add
    #|        br $l
    #|      else
    #|        local.get 1
    #|      end)))
    #|)
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    source, "typed loop-param backedge/body-local separation",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(text.contains("i32.const I32(100)"), msg=text)
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites typed loop-param control on the hot path" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $l (type $loop_t)
    #|      local.tee 1
    #|      local.get 0
    #|      i32.lt_s
    #|      if
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        br $l
    #|      end
    #|      local.get 1
    #|      drop
    #|    end
    #|    i32.const 1)
    #|)
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    source, "typed loop-param control on the hot path",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites typed loop-carried induction values" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    (local.get 0)
    #|    (loop $grow (type $loop_t)
    #|      local.tee 1
    #|      local.get 0
    #|      i32.lt_s
    #|      if (result i32)
    #|        local.get 1
    #|        i32.const 1
    #|        i32.shl
    #|        br $grow
    #|      else
    #|        local.get 1
    #|      end)))
    #|)
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    source, "typed loop-carried induction value",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(text.contains("i32.shl"), msg=text)
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
fn ssa_test_nested_cfg_hot_mutates(source : String) -> Unit raise {
  assert_true(
    ssa_test_hot_path_revision_changed(source),
    msg="expected hot-path rewrite for simple nested value block",
  )
}

///|
test "ssa-nomerge rewrites simple nested value-block local traffic" {
  let source =
    #|(module
    #|  (func (local i32)
    #|    (block (result i32)
    #|      i32.const 7
    #|      local.set 0
    #|      local.get 0)
    #|    drop
    #|    local.get 0
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge preserves reaching local from nested value-block local.set" {
  let source =
    #|(module
    #|  (func (local i32)
    #|    i32.const 3
    #|    local.set 0
    #|    (block (result i32)
    #|      i32.const 7
    #|      local.set 0
    #|      local.get 0)
    #|    drop
    #|    local.get 0
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested value-block prior-write hot-path success, got \{err}",
      )
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(3)"), msg=text)
  assert_true(text.contains("i32.const I32(7)"), msg=text)
  assert_true(text.contains("local.set"), msg=text)
  assert_false(text.contains("local.get (Local 0)"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
}

///|
test "ssa-nomerge handles simple nested value-block local.tee" {
  let source =
    #|(module
    #|  (func (local i32)
    #|    (block (result i32)
    #|      i32.const 7
    #|      local.tee 0)
    #|    drop
    #|    local.get 0
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested value-block tee hot-path success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ])
}

///|
test "ssa-nomerge preserves distinct locals around nested value-block traffic" {
  let source =
    #|(module
    #|  (func (local i32 i32)
    #|    i32.const 10
    #|    local.set 0
    #|    i32.const 20
    #|    local.set 1
    #|    (block (result i32)
    #|      local.get 0
    #|      i32.const 1
    #|      i32.add
    #|      local.set 0
    #|      local.get 0)
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 0
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested value-block two-local hot-path success, got \{err}")
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(10)"), msg=text)
  assert_true(text.contains("i32.const I32(20)"), msg=text)
  assert_true(text.contains("i32.add"), msg=text)
  assert_false(text.contains("local.get (Local 0)"), msg=text)
  assert_false(text.contains("local.set (Local 0)"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
  assert_true(text.contains("local.set"), msg=text)
}

///|
test "ssa-nomerge rewrites simple nested result-if local traffic" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 1
    #|      local.get 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge preserves reaching local from nested result-if arms" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    i32.const 3
    #|    local.set 1
    #|
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 1
    #|      local.get 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|
    #|    local.get 1
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested result-if prior-write hot-path success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(3)"), msg=text)
  assert_true(text.contains("i32.const I32(7)"), msg=text)
  assert_true(text.contains("i32.const I32(9)"), msg=text)
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
  assert_true(text.contains("if I32"), msg=text)
  assert_true(
    locals.length() > 2,
    msg="expected SSA temps beyond param and one body local, got \{locals}",
  )
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg="expected if-arm local writes to use SSA temps, got \{text}",
  )
}

///|
test "ssa-nomerge handles local.tee in simple nested result-if arm" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 7
    #|      local.tee 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested result-if tee hot-path success, got \{err}")
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(
    text.contains("local.tee") || text.contains("local.set"),
    msg=text,
  )
  assert_true(text.contains("local.get"), msg=text)
}

///|
test "ssa-nomerge preserves distinct locals around nested result-if traffic" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    i32.const 10
    #|    local.set 1
    #|    i32.const 20
    #|    local.set 2
    #|
    #|    local.get 0
    #|    if (result i32)
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.set 1
    #|      local.get 1
    #|    else
    #|      local.get 1
    #|      i32.const 2
    #|      i32.add
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|
    #|    local.get 2
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested result-if two-local hot-path success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(10)"), msg=text)
  assert_true(text.contains("i32.const I32(20)"), msg=text)
  assert_true(text.contains("i32.add"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("if I32"), msg=text)
  assert_true(
    locals.length() > 3,
    msg="expected SSA temps beyond param and two body locals, got \{locals}",
  )
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 2U),
    msg="expected if-arm local writes to use SSA temps above local 2, got \{text}",
  )
}

///|
test "ssa-nomerge rewrites simple nested result-if with i64 result" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i64)
    #|      i32.const 7
    #|      local.set 1
    #|      i64.const 70
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      i64.const 90
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge rewrites simple nested result-if with f32 result" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result f32)
    #|      i32.const 7
    #|      local.set 1
    #|      f32.const 7.0
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      f32.const 9.0
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge rewrites simple nested result-if with f64 result" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result f64)
    #|      i32.const 7
    #|      local.set 1
    #|      f64.const 7.0
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      f64.const 9.0
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge preserves i64 local traffic inside nested result-if" {
  let source =
    #|(module
    #|  (func (param i32) (local i64)
    #|    local.get 0
    #|    if (result i64)
    #|      i64.const 7
    #|      local.set 1
    #|      local.get 1
    #|    else
    #|      i64.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested i64 result-if hot-path success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i64.const"), msg=text)
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
  assert_true(
    locals.length() > 2,
    msg="expected SSA temps beyond param and one body local, got \{locals}",
  )
}

///|
test "ssa-nomerge preserves f32 local traffic inside nested result-if" {
  let source =
    #|(module
    #|  (func (param i32) (local f32)
    #|    local.get 0
    #|    if (result f32)
    #|      f32.const 7.0
    #|      local.set 1
    #|      local.get 1
    #|    else
    #|      f32.const 9.0
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested f32 result-if hot-path success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("f32.const"), msg=text)
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
  assert_true(
    locals.length() > 2,
    msg="expected SSA temps beyond param and one body local, got \{locals}",
  )
}

///|
test "ssa-nomerge preserves f64 local traffic inside nested result-if" {
  let source =
    #|(module
    #|  (func (param i32) (local f64)
    #|    local.get 0
    #|    if (result f64)
    #|      f64.const 7.0
    #|      local.set 1
    #|      local.get 1
    #|    else
    #|      f64.const 9.0
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested f64 result-if hot-path success, got \{err}")
  }
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("f64.const"), msg=text)
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
  assert_true(
    locals.length() > 2,
    msg="expected SSA temps beyond param and one body local, got \{locals}",
  )
}

///|
test "ssa-nomerge rewrites nested result-if with condition local.set" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    i32.const 1
    #|    local.set 1
    #|    local.get 1
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 1
    #|      local.get 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge rewrites nested result-if with condition local.tee" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    i32.const 1
    #|    local.tee 1
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 1
    #|      local.get 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested result-if condition tee hot-path success, got \{err}",
      )
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(
    text.contains("local.tee") || text.contains("local.set"),
    msg=text,
  )
  assert_true(text.contains("local.get"), msg=text)
}

///|
test "ssa-nomerge preserves condition-written local across nested result-if arms" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    i32.const 1
    #|    local.set 1
    #|    local.get 1
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 2
    #|      local.get 2
    #|    else
    #|      i32.const 9
    #|      local.set 2
    #|      local.get 2
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested result-if condition-written local preservation, got \{err}",
      )
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(1)"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
  assert_true(text.contains("local.set"), msg=text)
}

///|
test "ssa-nomerge lets nested result-if arms read condition-written locals" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    i32.const 4
    #|    local.set 1
    #|    local.get 0
    #|    if (result i32)
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.set 2
    #|      local.get 2
    #|    else
    #|      local.get 1
    #|      i32.const 2
    #|      i32.add
    #|      local.set 2
    #|      local.get 2
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested result-if arms reading condition-written local, got \{err}",
      )
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(4)"), msg=text)
  assert_true(text.contains("i32.add"), msg=text)
}

///|
test "ssa-nomerge handles scalar result-if with condition local write" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    i32.const 1
    #|    local.tee 1
    #|    if (result f64)
    #|      i32.const 7
    #|      local.set 1
    #|      f64.const 7.0
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      f64.const 9.0
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge rewrites nested result-if with condition value-block local.set" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    (block (result i32)
    #|      i32.const 1
    #|      local.set 1
    #|      local.get 1)
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 1
    #|      local.get 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge rewrites nested result-if with condition value-block local.tee" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    (block (result i32)
    #|      i32.const 1
    #|      local.tee 1)
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 1
    #|      local.get 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge preserves condition-block-written local across nested result-if arms" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    (block (result i32)
    #|      i32.const 1
    #|      local.set 1
    #|      local.get 1)
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 2
    #|      local.get 2
    #|    else
    #|      i32.const 9
    #|      local.set 2
    #|      local.get 2
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected condition-block-written local preservation hot-path success, got \{err}",
      )
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(1)"), msg=text)
  assert_true(text.contains("i32.const I32(7)"), msg=text)
  assert_true(text.contains("i32.const I32(9)"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
}

///|
test "ssa-nomerge lets nested result-if arms read condition-block-written locals" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    (block (result i32)
    #|      i32.const 4
    #|      local.set 1
    #|      local.get 0)
    #|    if (result i32)
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.set 2
    #|      local.get 2
    #|    else
    #|      local.get 1
    #|      i32.const 2
    #|      i32.add
    #|      local.set 2
    #|      local.get 2
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected arms-read-condition-block-local hot-path success, got \{err}",
      )
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(4)"), msg=text)
  assert_true(text.contains("i32.add"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
}

///|
test "ssa-nomerge handles scalar result-if with condition value-block" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    (block (result i32)
    #|      i32.const 1
    #|      local.set 1
    #|      local.get 1)
    #|    if (result f64)
    #|      i32.const 7
    #|      local.set 1
    #|      f64.const 7.0
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      f64.const 9.0
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with branch in condition block" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    block
    #|      (block (result i32)
    #|        i32.const 1
    #|        local.set 1
    #|        br 1
    #|        local.get 1)
    #|      if (result i32)
    #|        i32.const 7
    #|        local.set 1
    #|        local.get 1
    #|      else
    #|        i32.const 9
    #|        local.set 1
    #|        local.get 1
    #|      end
    #|      drop
    #|    end
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with br_if in condition block" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    block
    #|      (block (result i32)
    #|        i32.const 1
    #|        local.set 1
    #|        i32.const 1
    #|        br_if 1
    #|        local.get 1)
    #|      if (result i32)
    #|        i32.const 7
    #|        local.set 1
    #|        local.get 1
    #|      else
    #|        i32.const 9
    #|        local.set 1
    #|        local.get 1
    #|      end
    #|      drop
    #|    end
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with nested loop in condition block" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    (block (result i32)
    #|      loop
    #|        i32.const 1
    #|        local.set 1
    #|      end
    #|      local.get 1)
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 1
    #|      local.get 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge rejects unsupported nested result-if with non-i32 condition block result" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let condition_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i64()),
    [@ir.hot_build_const_i64(func, @lib.I64(1))],
  )
  let result_if = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    condition_block,
    [
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(7)),
      ),
      @ir.hot_build_local_get(func, 1),
    ],
    else_body=Some([
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(9)),
      ),
      @ir.hot_build_local_get(func, 1),
    ]),
  )
  let drop = @ir.hot_build_drop(func, result_if)
  @ir.hot_root_append(func, drop)
  @ir.hot_root_append(
    func,
    @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)),
  )
  assert_false(
    @ir.ssa_simple_drop_result_if_allowed(func, drop, 0, result_if),
    msg="non-i32 condition block is unsupported boundary",
  )
  ssa_test_hot_func_ssa_nomerge_revision_unchanged(func)
}

///|
test "ssa-nomerge rejects unsupported nested result-if with branch in condition" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let outer = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let condition_br = @ir.hot_build_br(
    func,
    @ir.hot_control_node_label(func, outer),
  )
  let result_if = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    condition_br,
    [
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(7)),
      ),
      @ir.hot_build_local_get(func, 1),
    ],
    else_body=Some([
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(9)),
      ),
      @ir.hot_build_local_get(func, 1),
    ]),
  )
  let drop = @ir.hot_build_drop(func, result_if)
  @ir.hot_root_append(func, drop)
  @ir.hot_root_append(
    func,
    @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)),
  )
  assert_false(
    @ir.ssa_simple_drop_result_if_allowed(func, drop, 0, result_if),
    msg="branch in condition is unsupported boundary",
  )
  ssa_test_hot_func_ssa_nomerge_revision_unchanged(func)
}

///|
test "ssa-nomerge rewrites drop operand result-if with simple condition value-block" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    (if (result i32)
    #|      (block (result i32)
    #|        (i32.const 1)
    #|        (local.set 1)
    #|        (local.get 1))
    #|      (then
    #|        (i32.const 7)
    #|        (local.set 1)
    #|        (local.get 1))
    #|      (else
    #|        (i32.const 9)
    #|        (local.set 1)
    #|        (local.get 1)))
    #|    drop
    #|    (local.get 1)
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge rewrites nested result-if with value-block arms" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.set 1
    #|        local.get 1)
    #|    else
    #|      (block (result i32)
    #|        i32.const 9
    #|        local.set 1
    #|        local.get 1)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge rewrites nested result-if with one value-block arm" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.set 1
    #|        local.get 1)
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge handles local.tee inside result-if arm value-block" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.tee 1)
    #|    else
    #|      (block (result i32)
    #|        i32.const 9
    #|        local.set 1
    #|        local.get 1)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge lets arm value-blocks read condition-written locals" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    i32.const 4
    #|    local.set 1
    #|    local.get 0
    #|    if (result i32)
    #|      (block (result i32)
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.set 2
    #|        local.get 2)
    #|    else
    #|      (block (result i32)
    #|        local.get 1
    #|        i32.const 2
    #|        i32.add
    #|        local.set 2
    #|        local.get 2)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge handles scalar result-if with scalar arm value-blocks" {
  let source =
    #|(module
    #|  (func (param i32) (local f64)
    #|    local.get 0
    #|    if (result f64)
    #|      (block (result f64)
    #|        f64.const 7.0
    #|        local.set 1
    #|        local.get 1)
    #|    else
    #|      (block (result f64)
    #|        f64.const 9.0
    #|        local.set 1
    #|        local.get 1)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge handles condition value-block plus arm value-blocks" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    (block (result i32)
    #|      i32.const 1
    #|      local.set 1
    #|      local.get 1)
    #|    if (result i32)
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.set 2
    #|        local.get 2)
    #|    else
    #|      (block (result i32)
    #|        i32.const 9
    #|        local.set 2
    #|        local.get 2)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with branch in arm value-block" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.set 1
    #|        block
    #|          br 0
    #|        end
    #|        local.get 1)
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with br_if in arm value-block" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.set 1
    #|        block
    #|          i32.const 0
    #|          br_if 0
    #|        end
    #|        local.get 1)
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with nested if in arm value-block" {
  let source =
    #|(module
    #|  (func (param i32 i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      (block (result i32)
    #|        local.get 1
    #|        if
    #|          i32.const 7
    #|          local.set 2
    #|        end
    #|        local.get 2)
    #|    else
    #|      i32.const 9
    #|      local.set 2
    #|      local.get 2
    #|    end
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with nested loop in arm value-block" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      (block (result i32)
    #|        loop
    #|          i32.const 7
    #|          local.set 1
    #|        end
    #|        local.get 1)
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge rewrites nested result-if with void prefixes before arm value-blocks" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 1
    #|      local.set 1
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.set 2
    #|        local.get 2)
    #|    else
    #|      i32.const 2
    #|      local.set 1
    #|      (block (result i32)
    #|        i32.const 9
    #|        local.set 2
    #|        local.get 2)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge rewrites nested result-if with one mixed arm value-block" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 1
    #|      local.set 1
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.set 2
    #|        local.get 2)
    #|    else
    #|      (block (result i32)
    #|        i32.const 9
    #|        local.set 2
    #|        local.get 2)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge lets arm value-blocks read prefix-written locals" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 4
    #|      local.set 1
    #|      (block (result i32)
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        local.set 2
    #|        local.get 2)
    #|    else
    #|      i32.const 5
    #|      local.set 1
    #|      (block (result i32)
    #|        local.get 1
    #|        i32.const 2
    #|        i32.add
    #|        local.set 2
    #|        local.get 2)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge handles condition value-block plus mixed arm roots" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 i32 i32)
    #|    (block (result i32)
    #|      i32.const 1
    #|      local.set 1
    #|      local.get 1)
    #|    if (result i32)
    #|      i32.const 4
    #|      local.set 2
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.set 3
    #|        local.get 3)
    #|    else
    #|      i32.const 5
    #|      local.set 2
    #|      (block (result i32)
    #|        i32.const 9
    #|        local.set 3
    #|        local.get 3)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop
    #|    local.get 3
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge handles scalar result-if with mixed scalar arm value-blocks" {
  let source =
    #|(module
    #|  (func (param i32) (local i32 f64)
    #|    local.get 0
    #|    if (result f64)
    #|      i32.const 1
    #|      local.set 1
    #|      (block (result f64)
    #|        f64.const 7.0
    #|        local.set 2
    #|        local.get 2)
    #|    else
    #|      i32.const 2
    #|      local.set 1
    #|      (block (result f64)
    #|        f64.const 9.0
    #|        local.set 2
    #|        local.get 2)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge handles drop prefixes before arm value-blocks" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 123
    #|      drop
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.set 1
    #|        local.get 1)
    #|    else
    #|      i32.const 456
    #|      drop
    #|      (block (result i32)
    #|        i32.const 9
    #|        local.set 1
    #|        local.get 1)
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_nested_cfg_hot_mutates(source)
}

///|
test "ssa-nomerge rejects mixed arm with value-producing prefix root" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let then_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(7)),
      ),
      @ir.hot_build_local_get(func, 1),
    ],
  )
  let result_if = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_local_get(func, 0),
    [@ir.hot_build_const_i32(func, @lib.I32(111)), then_block],
    else_body=Some([
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(9)),
      ),
      @ir.hot_build_local_get(func, 1),
    ]),
  )
  let drop = @ir.hot_build_drop(func, result_if)
  @ir.hot_root_append(func, drop)
  @ir.hot_root_append(
    func,
    @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)),
  )
  assert_false(
    @ir.ssa_simple_drop_result_if_allowed(func, drop, 0, result_if),
    msg="value-producing mixed-arm prefix is unsupported boundary",
  )
  ssa_test_hot_func_ssa_nomerge_revision_unchanged(func)
}

///|
test "ssa-nomerge rejects mixed arm with roots after final value-block" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let then_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(7)),
      ),
      @ir.hot_build_local_get(func, 1),
    ],
  )
  let result_if = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_local_get(func, 0),
    [
      then_block,
      @ir.hot_build_drop(func, @ir.hot_build_const_i32(func, @lib.I32(222))),
    ],
    else_body=Some([
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(9)),
      ),
      @ir.hot_build_local_get(func, 1),
    ]),
  )
  let drop = @ir.hot_build_drop(func, result_if)
  @ir.hot_root_append(func, drop)
  @ir.hot_root_append(
    func,
    @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)),
  )
  assert_false(
    @ir.ssa_simple_drop_result_if_allowed(func, drop, 0, result_if),
    msg="roots after final mixed-arm value block are unsupported boundary",
  )
  ssa_test_hot_func_ssa_nomerge_revision_unchanged(func)
}

///|
test "ssa-nomerge rejects mixed arm with two value-block roots" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let first_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [@ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let second_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(8)),
      ),
      @ir.hot_build_local_get(func, 1),
    ],
  )
  let result_if = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_local_get(func, 0),
    [first_block, second_block],
    else_body=Some([
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(9)),
      ),
      @ir.hot_build_local_get(func, 1),
    ]),
  )
  let drop = @ir.hot_build_drop(func, result_if)
  @ir.hot_root_append(func, drop)
  @ir.hot_root_append(
    func,
    @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)),
  )
  assert_false(
    @ir.ssa_simple_drop_result_if_allowed(func, drop, 0, result_if),
    msg="two mixed-arm value blocks are unsupported boundary",
  )
  ssa_test_hot_func_ssa_nomerge_revision_unchanged(func)
}

///|
test "ssa-nomerge rejects unsupported mixed arm with branch in final value-block" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let prefix = @ir.hot_build_local_set(
    func,
    1,
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  let outer_block = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let then_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [
      @ir.hot_build_br(func, @ir.hot_control_node_label(func, outer_block)),
      @ir.hot_build_local_get(func, 1),
    ],
  )
  let result_if = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_local_get(func, 0),
    [prefix, then_block],
    else_body=Some([
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(9)),
      ),
      @ir.hot_build_local_get(func, 1),
    ]),
  )
  let drop = @ir.hot_build_drop(func, result_if)
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, outer_block),
    [drop],
  )
  @ir.hot_root_append(func, outer_block)
  @ir.hot_root_append(
    func,
    @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)),
  )
  assert_false(
    @ir.ssa_simple_drop_result_if_allowed(func, drop, 0, result_if),
    msg="branch inside mixed-arm final value block is unsupported boundary",
  )
  ssa_test_hot_func_ssa_nomerge_revision_unchanged(func)
}

///|
test "ssa-nomerge rejects mixed arm value-block result type mismatch" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let prefix = @ir.hot_build_local_set(
    func,
    1,
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  let then_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i64()),
    [
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i64(func, @lib.I64(7)),
      ),
      @ir.hot_build_local_get(func, 1),
    ],
  )
  let else_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(9)),
      ),
      @ir.hot_build_local_get(func, 1),
    ],
  )
  let result_if = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_local_get(func, 0),
    [prefix, then_block],
    else_body=Some([else_block]),
  )
  let drop = @ir.hot_build_drop(func, result_if)
  @ir.hot_root_append(func, drop)
  @ir.hot_root_append(
    func,
    @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)),
  )
  assert_false(
    @ir.ssa_simple_drop_result_if_allowed(func, drop, 0, result_if),
    msg="mixed arm value-block result type mismatch is unsupported boundary",
  )
  ssa_test_hot_func_ssa_nomerge_revision_unchanged(func)
}

///|
test "ssa-nomerge does not mutate unsupported mixed arm with nested block inside final value-block" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 1
    #|      local.set 1
    #|      (block (result i32)
    #|        (block
    #|          i32.const 7
    #|          local.set 1)
    #|        local.get 1)
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge rejects arm value-block result type mismatch" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let then_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i64()),
    [
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i64(func, @lib.I64(7)),
      ),
      @ir.hot_build_local_get(func, 1),
    ],
  )
  let else_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(9)),
      ),
      @ir.hot_build_local_get(func, 1),
    ],
  )
  let result_if = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_local_get(func, 0),
    [then_block],
    else_body=Some([else_block]),
  )
  let drop = @ir.hot_build_drop(func, result_if)
  @ir.hot_root_append(func, drop)
  @ir.hot_root_append(
    func,
    @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 1)),
  )
  assert_false(
    @ir.ssa_simple_drop_result_if_allowed(func, drop, 0, result_if),
    msg="arm value-block result type mismatch is unsupported boundary",
  )
  ssa_test_hot_func_ssa_nomerge_revision_unchanged(func)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with nested if in condition" {
  let source =
    #|(module
    #|  (func (param i32 i32) (local i32)
    #|    (if (result i32)
    #|      (if (result i32) (local.get 0)
    #|        (then (i32.const 1))
    #|        (else (i32.const 0)))
    #|      (then
    #|        (i32.const 7)
    #|        (local.set 1)
    #|        (local.get 1))
    #|      (else
    #|        (i32.const 9)
    #|        (local.set 1)
    #|        (local.get 1)))
    #|    drop
    #|    (local.get 1)
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge rewrites nested result-if when one arm does not overwrite condition local" {
  // Phi placement records the condition-written reaching def for the non-writing arm
  // and the arm overwrite for the other predecessor; CFG-backed rename visits the
  // condition in the shared predecessor block before both arms.
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    i32.const 1
    #|    local.tee 1
    #|    if (result i32)
    #|      local.get 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  let optimized = match ssa_test_run_hot_path_only(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected one-arm-non-overwrite condition-write hot-path success, got \{err}",
      )
  }
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(1)"), msg=text)
  assert_true(text.contains("i32.const I32(9)"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with multi-value result" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32 i32)
    #|      i32.const 7
    #|      local.set 1
    #|      local.get 1
    #|      i32.const 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|      i32.const 2
    #|    end
    #|    drop
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with br" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    (block $outer
    #|      local.get 0
    #|      if (result i32)
    #|        i32.const 7
    #|        local.set 1
    #|        br $outer
    #|        local.get 1
    #|      else
    #|        i32.const 9
    #|        local.set 1
    #|        local.get 1
    #|      end
    #|      drop)
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with br_if" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    (block $outer
    #|      local.get 0
    #|      if (result i32)
    #|        i32.const 7
    #|        local.set 1
    #|        i32.const 1
    #|        br_if $outer
    #|        local.get 1
    #|      else
    #|        i32.const 9
    #|        local.set 1
    #|        local.get 1
    #|      end
    #|      drop)
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with nested loop" {
  let source =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      loop
    #|        i32.const 7
    #|        local.set 1
    #|      end
    #|      local.get 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|      local.get 1
    #|    end
    #|    drop
    #|    local.get 1
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if with nested if" {
  let source =
    #|(module
    #|  (func (param i32 i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      local.get 1
    #|      if
    #|        i32.const 7
    #|        local.set 2
    #|      end
    #|      local.get 2
    #|    else
    #|      i32.const 9
    #|      local.set 2
    #|      local.get 2
    #|    end
    #|    drop
    #|    local.get 2
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested result-if under value block" {
  // The result-typed `if` arms are region roots, but the enclosing value block
  // sits in `drop`'s operand slot and is therefore nested CFG-sensitive control.
  let source =
    #|(module
    #|  (func (param i32) (result i32)
    #|    (local i32)
    #|    (block (result i32)
    #|      local.get 0
    #|      if (result i32)
    #|        i32.const 10
    #|        local.set 1
    #|        local.get 1
    #|      else
    #|        i32.const 20
    #|        local.set 1
    #|        local.get 1
    #|      end)
    #|    drop
    #|    local.get 1))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
  ssa_test_nested_cfg_hot_local_traffic_preserved(source)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
}

///|
test "ssa-nomerge does not mutate unsupported nested value block with br" {
  // `br` is a terminator; when it appears inside a value block nested under
  // `drop`, the guard treats the subtree as nested CFG-sensitive local traffic.
  // An outer `$outer` label gives the inner `br` a valid exit target.
  let source =
    #|(module
    #|  (func (param i32) (result i32)
    #|    (local i32)
    #|    (block $outer
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.set 1
    #|        br $outer
    #|        local.get 1)
    #|      drop)
    #|    local.get 1))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
}

///|
test "ssa-nomerge does not mutate unsupported nested value block with br_if" {
  // `br_if` is branch-shaped but not a HOT terminator flag; this fixture still
  // triggers the guard via the nested value block under `drop` with local traffic.
  // The outer `$outer` label keeps the inner `br_if` stack-valid.
  let source =
    #|(module
    #|  (func (param i32) (result i32)
    #|    (local i32)
    #|    (block $outer
    #|      (block (result i32)
    #|        i32.const 7
    #|        local.set 1
    #|        i32.const 1
    #|        br_if $outer
    #|        local.get 1)
    #|      drop)
    #|    local.get 1))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
}

///|
test "ssa-nomerge does not mutate unsupported nested loop under value block" {
  let source =
    #|(module
    #|  (func (local i32)
    #|    (block (result i32)
    #|      loop
    #|        i32.const 7
    #|        local.set 0
    #|      end
    #|      local.get 0)
    #|    drop
    #|    local.get 0
    #|    drop))
    #|)
  ssa_test_unsupported_nested_cfg_pipeline_no_mutation(source)
  ssa_test_unsupported_nested_cfg_hot_no_mutation(source)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
}

///|
test "ssa-nomerge keeps straight-line local traffic on the canonical slot" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 5 local.set 0 local.get 0))",
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
}

///|
test "ssa-nomerge keeps call result assigned when a later loop reads the local" {
  let source =
    #|(module
    #|  (func $to_string (param i32) (result i32)
    #|    local.get 0)
    #|  (func $add_string (param i32 i32) (result i32)
    #|    local.get 1)
    #|  (func $decref (param i32))
    #|  (func $iter (param i32) (result i32)
    #|    local.get 0)
    #|  (func $next (param i32) (result i32)
    #|    local.get 0)
    #|  (func $write_char (param i32 i32))
    #|  (func (param i32 i32 i32) (result i32)
    #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|    local.get 1
    #|    call $to_string
    #|    local.set 14
    #|    local.get 14
    #|    call $decref
    #|    local.get 12
    #|    call $decref
    #|    i32.const 21800
    #|    local.get 14
    #|    call $add_string
    #|    i32.const 21776
    #|    call $add_string
    #|    local.set 16
    #|    local.get 2
    #|    call $to_string
    #|    local.set 17
    #|    local.get 17
    #|    call $decref
    #|    local.get 16
    #|    call $decref
    #|    local.get 9
    #|    call $decref
    #|    local.get 16
    #|    local.get 17
    #|    call $add_string
    #|    i32.const 12080
    #|    call $add_string
    #|    call $iter
    #|    local.set 3
    #|    loop
    #|      block (result i32)
    #|        block
    #|          local.get 3
    #|          call $next
    #|          local.tee 5
    #|          i32.const -1
    #|          i32.eq
    #|          if
    #|            local.get 0
    #|            call $decref
    #|            local.get 3
    #|            call $decref
    #|          else
    #|            local.get 5
    #|            local.set 4
    #|            br 1
    #|          end
    #|          i32.const 0
    #|          br 1
    #|        end
    #|        local.get 0
    #|        local.get 4
    #|        call $write_char
    #|        br 1
    #|      end
    #|      drop
    #|    end
    #|    i32.const 0))
    #|)
  let optimized = match pass_test_run_pipeline(source, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected call-result loop ssa-nomerge success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_defined_func(optimized, 6)
  assert_false(
    ssa_test_has_adjacent_call_drop(instrs, 3U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge keeps the latest straight-line local alias live" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result f64) (local f64) f64.const 69 local.tee 0 drop f64.const 39 local.tee 0 drop local.get 0))",
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected straight-line alias replay success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::f64(),
      @lib.ValType::f64(),
      @lib.ValType::f64(),
    ]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::f64_const(@lib.F64(69.0)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::f64_const(@lib.F64(39.0)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  ])
}

///|
fn ssa_test_large_structured_branch_fixture() -> String {
  let out = StringBuilder::new()
  out.write_string("(module (func (local i32")
  for i = 0; i < 64; i = i + 1 {
    out.write_string(" i32")
  }
  out.write_string(") block i32.const 0 br 0 end i32.const 1 local.set 64))")
  out.to_string()
}

///|
fn ssa_test_assert_raw_structured_rewrite_added_alias_local(
  optimized : @lib.Module,
  original_local_count : Int,
  context : String,
) -> Unit raise {
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(
    locals.length() > original_local_count,
    msg="expected \{context} to add an SSA alias local; locals=\{locals}",
  )
  assert_true(instrs.to_string().contains("local.set"), msg=instrs.to_string())
}

///|
test "ssa-nomerge rewrites moderately large structured branch functions without hot fallback" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      ssa_test_large_structured_branch_fixture(),
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected moderately large structured ssa-nomerge success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=large-structured-local-writes",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  ssa_test_assert_raw_structured_rewrite_added_alias_local(
    optimized, 65, "moderately large structured branch raw rewrite",
  )
}

///|
fn ssa_test_large_structured_local_write_fixture(if_count : Int) -> String {
  let out = StringBuilder::new()
  out.write_string("(module (func (local i32) ")
  for i = 0; i < if_count; i = i + 1 {
    out.write_string("i32.const 0 if nop else nop end ")
  }
  out.write_string("i32.const 1 local.set 0))")
  out.to_string()
}

///|
test "ssa-nomerge rewrites very large structured local-write functions without branches" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      ssa_test_large_structured_local_write_fixture(130),
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected large structured local-write ssa-nomerge rewrite success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=large-structured-local-writes",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  ssa_test_assert_raw_structured_rewrite_added_alias_local(
    optimized, 1, "large no-branch raw rewrite",
  )
}

///|
test "ssa-nomerge keeps audited high-threshold structured local-write functions without branches on raw path" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      ssa_test_large_structured_local_write_fixture(2047),
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected audited high-threshold no-branch ssa-nomerge success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=large-structured-local-writes",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("skip-invalid-lower") }),
    msg=trace.join("\n"),
  )
  ssa_test_assert_raw_structured_rewrite_added_alias_local(
    optimized, 1, "high-threshold no-branch raw rewrite",
  )
}

///|
test "ssa-nomerge keeps larger no-branch structured functions above raw threshold classified as large" {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      ssa_test_large_structured_local_write_fixture(2048),
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected above-threshold no-branch ssa-nomerge success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=large-structured-local-writes",
      ) &&
      line.contains("instrs=")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("skip-invalid-lower") }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
}

///|
fn ssa_test_large_structured_branch_if_prefix_fixture(if_count : Int) -> String {
  let out = StringBuilder::new()
  out.write_string("(module (func (local i32) block i32.const 0 br 0 end ")
  for i = 0; i < if_count; i = i + 1 {
    out.write_string("i32.const 0 if nop else nop end ")
  }
  out.write_string("i32.const 1 local.set 0))")
  out.to_string()
}

///|
test "ssa-nomerge keeps structured branch functions below raw instruction threshold on raw path" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      ssa_test_large_structured_branch_if_prefix_fixture(1020),
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected below-threshold structured branch ssa-nomerge success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=large-structured-local-writes",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("skip-invalid-lower") }),
    msg=trace.join("\n"),
  )
  ssa_test_assert_raw_structured_rewrite_added_alias_local(
    optimized, 1, "below-threshold structured branch raw rewrite",
  )
}

///|
test "ssa-nomerge keeps audited high-threshold structured branch functions on raw path" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      ssa_test_large_structured_branch_if_prefix_fixture(2046),
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected audited high-threshold structured branch ssa-nomerge success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=large-structured-local-writes",
      )
    }),
    msg=trace.join("\n"),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("skip-invalid-lower") }),
    msg=trace.join("\n"),
  )
  ssa_test_assert_raw_structured_rewrite_added_alias_local(
    optimized, 1, "high-threshold structured branch raw rewrite",
  )
}

///|
test "ssa-nomerge classifies structured branch functions above raw instruction threshold as large-structured-local-writes" {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      ssa_test_large_structured_branch_if_prefix_fixture(2047),
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected above-threshold structured branch ssa-nomerge success, got \{err}",
      )
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=large-structured-local-writes",
      ) &&
      line.contains("instrs=")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("skip-invalid-lower") }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge rewrites default local reads after branchy control without hot fallback" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) block i32.const 0 br_table 0 0 end local.get 0))",
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected branchy default-read rewrite success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(0)"), msg=text)
  assert_false(text.contains("local.get"), msg=text)
}

///|
test "ssa-nomerge removes dropped unreachable debris before a following unreachable" {
  let source =
    #|(module
    #|  (func
    #|    (block (result i32)
    #|      unreachable
    #|      unreachable)
    #|    unreachable))
    #|)
  let optimized = match pass_test_run_pipeline(source, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected unreachable-debris rewrite success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("unreachable"), msg=text)
  assert_false(text.contains("(block"), msg=text)
  assert_false(text.contains("Drop"), msg=text)
}

///|
test "ssa-nomerge rewrites dead param sets through fresh locals" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i64) (result i32) i64.const 756 local.set 0 i32.const 700))",
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dead param set rewrite success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i64()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::i64_const(@lib.I64(756L)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(700)),
  ])
}

///|
test "ssa-nomerge rewrites dead param tees through fresh locals" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param f64) (result f32) f64.const 17 local.tee 0 drop f32.const 92))",
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dead param tee rewrite success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::f64()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::f64_const(@lib.F64(17.0)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::f32_const(@lib.F32::new(92.0)),
  ])
}

///|
test "ssa-nomerge keeps structured param writes on the canonical slot" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     i32.const 0
    #|     if
    #|       nop
    #|     else
    #|       nop
    #|     end
    #|     i32.const 1
    #|     if
    #|       nop
    #|     else
    #|       nop
    #|     end
    #|     i32.const 819
    #|     local.tee 0
    #|     drop
    #|     local.get 0))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected structured param slot reuse success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::nop()],
      Some([@lib.Instruction::nop()]),
    ),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::nop()],
      Some([@lib.Instruction::nop()]),
    ),
    @lib.Instruction::i32_const(@lib.I32(819)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
}

///|
test "ssa-nomerge keeps body-local writes canonical before next read" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     local.get 0
    #|     if
    #|       i32.const 1
    #|       local.set 1
    #|       local.get 1
    #|       drop
    #|     end
    #|     i32.const 2
    #|     local.set 1
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected body-local canonical rewrite success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs.to_string().contains("Local 2"), false)
}

///|
test "ssa-nomerge keeps nested structured param write canonical before next read" {
  let input =
    #| (module
    #|   (func (param i32) (param i32) (result i32)
    #|     (local i32)
    #|     local.get 1
    #|     i32.const 256
    #|     i32.lt_u
    #|     if (result i32)
    #|       local.get 1
    #|       i32.const 4
    #|       i32.shr_u
    #|       local.set 1
    #|       i32.const 0
    #|     else
    #|       local.get 1
    #|       i32.const 536870910
    #|       i32.lt_u
    #|       if
    #|         local.get 1
    #|         i32.const 1
    #|         i32.add
    #|         local.set 1
    #|       end
    #|       i32.const 31
    #|       local.get 1
    #|       i32.clz
    #|       i32.sub
    #|       local.set 2
    #|       local.get 1
    #|       local.get 2
    #|       i32.const 4
    #|       i32.sub
    #|       i32.shr_u
    #|       i32.const 16
    #|       i32.xor
    #|       local.set 1
    #|       local.get 2
    #|       i32.const 7
    #|       i32.sub
    #|     end
    #|     local.get 1
    #|     i32.add))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested structured param rewrite success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs.to_string().contains("Local 3"), false)
}

///|
test "ssa-nomerge avoids canonical copies for block-exit locals not read later" {
  let input =
    #| (module
    #|   (func (result i32)
    #|     (local i32 i32)
    #|     block
    #|       i32.const 7
    #|       local.set 0
    #|       br 0
    #|     end
    #|     i32.const 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected unneeded block-exit rewrite success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_false(text.contains("i32.const I32(0)"), msg=text)
  assert_false(text.contains("local.set (Local 0)"), msg=text)
}

///|
test "ssa-nomerge avoids default merge copies for branch locals not read later" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32 i32 i32)
    #|     local.get 0
    #|     if (result i32)
    #|       i32.const 10
    #|       local.set 1
    #|       i32.const 1
    #|     else
    #|       local.get 0
    #|       i32.const 2
    #|       i32.eq
    #|       if (result i32)
    #|         i32.const 20
    #|         local.set 2
    #|         i32.const 2
    #|       else
    #|         i32.const 30
    #|         local.set 3
    #|         i32.const 3
    #|       end
    #|     end))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected unneeded branch-local rewrite success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_false(text.contains("i32.const I32(0)"), msg=text)
  assert_false(text.contains("Local 7"), msg=text)
}

///|
test "ssa-nomerge rewrites func4302-style returning carriers without suspicious skip" {
  let trace : Array[String] = []
  let input =
    #| (module
    #|   (func $dec (param i32))
    #|   (func $len (param i32) (result i32) local.get 0)
    #|   (func (param i64 i32) (result i32)
    #|     (local i32 i32)
    #|     (block
    #|       (if (result i32) (i64.eq (local.get 0) (i64.const 4294967296))
    #|         (then
    #|           (if (local.get 1) (then (call $dec (local.get 1))))
    #|           (i32.const 0))
    #|         (else
    #|           (local.set 2 (i32.wrap_i64 (local.get 0)))
    #|           (br 1)))
    #|       return)
    #|     (local.set 3
    #|       (block (result i32)
    #|         (block
    #|           (if (result i32) (i32.eqz (local.get 1))
    #|             (then
    #|               (if (local.get 1) (then (call $dec (local.get 1))))
    #|               (if (result i32) (i32.eqz (local.get 2))
    #|                 (then (i32.const 0))
    #|                 (else (return (i32.const 4)))))
    #|             (else
    #|               (local.set 2 (local.get 1))
    #|               (br 1)))
    #|           (br 1))
    #|         (call $len (local.get 2))))
    #|     (i32.eq (local.get 2) (local.get 3))))
    #|
  match
    pass_test_run_pipeline(
      input,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected func4302-style ssa-nomerge success, got \{err}")
  }
  assert_false(
    trace.any(fn(line) { line.contains("skip-invalid-lower") }),
    msg=trace.join("\n"),
  )
}

///|
test "ssa-nomerge keeps branch joins canonical when the next read is safe" {
  let input =
    #| (module
    #|   (func (result i32)
    #|     (local i32)
    #|     i32.const 1
    #|     local.set 0
    #|     i32.const 1
    #|     if
    #|       i32.const 7
    #|       local.set 0
    #|     else
    #|       nop
    #|     end
    #|     local.get 0))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected branch-join ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      ],
      Some([@lib.Instruction::nop()]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
}

///|
test "ssa-nomerge rewrites loop-carried locals before br_if backedges" {
  let input =
    #| (module
    #|   (func (result i32)
    #|     (local i32)
    #|     i32.const 1
    #|     local.set 0
    #|     block
    #|       loop
    #|         local.get 0
    #|         drop
    #|         i32.const 2
    #|         local.set 0
    #|         i32.const 1
    #|         br_if 0
    #|       end
    #|     end
    #|     local.get 0))
    #|
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    input, "loop-carried locals before br_if backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_scalar_br_if_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge skips synthetic entry copies for root loop headers" {
  let input =
    #| (module
    #|   (func (param i32)
    #|     (local i32)
    #|     loop
    #|       local.get 1
    #|       local.get 0
    #|       i32.lt_s
    #|       if
    #|         local.get 1
    #|         i32.const 1
    #|         i32.add
    #|         local.set 1
    #|         br 1
    #|       end
    #|     end))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected root-loop ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_lt_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ],
          None,
        ),
      ]),
    ),
  ])
}

///|
test "ssa-nomerge rewrites structured early-return local traffic without hot lift" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     local.get 0
    #|     if
    #|       i32.const 7
    #|       local.set 1
    #|       local.get 1
    #|       return
    #|     else
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected structured raw ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::return_(),
      ],
      Some([
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
}

///|
test "ssa-nomerge keeps body-local tees canonical before branch continuation read" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     block
    #|       i32.const 7
    #|       local.tee 1
    #|       drop
    #|       br 0
    #|     end
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected branch-continuation tee rewrite success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_false(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge keeps result-branch tees canonical before continuation read" {
  let input =
    #| (module
    #|   (func (result i32)
    #|     (local i32)
    #|     block (result i32)
    #|       i32.const 7
    #|       local.tee 0
    #|       br 0
    #|     end
    #|     local.get 0
    #|     i32.add))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected result-branch tee rewrite success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_false(
    ssa_test_has_ssa_temp_local_writes(instrs, 0U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites block-target branches through canonical locals" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     i32.const 0
    #|     local.set 1
    #|     block
    #|       local.get 0
    #|       if
    #|         i32.const 7
    #|         local.set 1
    #|         br 1
    #|       end
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected block-target raw ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ],
          None,
        ),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
}

///|
test "ssa-nomerge preserves enclosing label copies after divergent branch aliases" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     block
    #|       local.get 0
    #|       if
    #|         i32.const 7
    #|         local.set 1
    #|       else
    #|         i32.const 8
    #|         local.set 1
    #|       end
    #|       block
    #|         br 1
    #|       end
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected enclosing-label copy rewrite success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
          ],
          Some([
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
          ]),
        ),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ]),
        ),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
}

///|
test "ssa-nomerge preserves no-copy block-target br_if" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     i32.const 7
    #|     local.set 1
    #|     block
    #|       local.get 0
    #|       br_if 0
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected block-target br_if raw ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
}

///|
test "ssa-nomerge preserves no-copy br_on_non_null on raw path" {
  let trace : Array[String] = []
  let ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let non_null_ref_type = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([ref_type], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(1U)]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(non_null_ref_type),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32::new(7)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32::new(1)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected br_on_non_null raw ssa-nomerge success, got \{err}")
  }

  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("hot-lift-error") }),
    msg=trace.join("\n"),
  )
  let (locals, instrs) = try! ssa_test_defined_func(optimized, 1)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge preserves no-copy br_on_cast on raw path" {
  let trace : Array[String] = []
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref_type = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let i31_ref_type = @lib.ValType::ref_type(@lib.RefType::new(false, i31_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([any_ref_type], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(i31_ref_type),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32::new(7)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_cast(
                  @lib.LabelIdx::new(0U),
                  true,
                  any_heap,
                  false,
                  i31_heap,
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(42)),
                @lib.Instruction::ref_i31(),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32::new(1)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected br_on_cast raw ssa-nomerge success, got \{err}")
  }

  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("hot-lift-error") }),
    msg=trace.join("\n"),
  )
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites br_on_cast taken-edge copies after divergent aliases" {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref_type = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let i31_ref_type = @lib.ValType::ref_type(@lib.RefType::new(false, i31_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([any_ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(i31_ref_type),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_cast(
                  @lib.LabelIdx::new(0U),
                  true,
                  any_heap,
                  false,
                  i31_heap,
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(42)),
                @lib.Instruction::ref_i31(),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "br_on_cast taken-edge copies after divergent aliases",
  )
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 2U, true),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites multi-result br_on_cast taken-edge copies" {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref_type = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let i31_ref_type = @lib.ValType::ref_type(@lib.RefType::new(false, i31_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([any_ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), i31_ref_type]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::i32_const(@lib.I32::new(99)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_cast(
                  @lib.LabelIdx::new(0U),
                  true,
                  any_heap,
                  false,
                  i31_heap,
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::i32_const(@lib.I32::new(42)),
                @lib.Instruction::ref_i31(),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "multi-result br_on_cast taken-edge copies",
  )
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 2U, true),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge does not mutate no-copy loop-target br_on_non_null with typed loop param" {
  let trace : Array[String] = []
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let non_null_any_ref_type = @lib.ValType::ref_type(
    @lib.RefType::new(false, any_heap),
  )
  let nullable_any_ref_type = @lib.ValType::ref_type(
    @lib.RefType::new(true, any_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([non_null_any_ref_type], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([non_null_any_ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), nullable_any_ref_type]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected loop-target br_on_non_null raw ssa-nomerge success, got \{err}",
      )
  }

  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("hot-lift-error") }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_non_null_proxy(instrs),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing loop-target br_on_non_null with typed loop param" {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let non_null_any_ref_type = @lib.ValType::ref_type(
    @lib.RefType::new(false, any_heap),
  )
  let nullable_any_ref_type = @lib.ValType::ref_type(
    @lib.RefType::new(true, any_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([non_null_any_ref_type], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([non_null_any_ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::i32(), nullable_any_ref_type]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "copy-needing loop-target br_on_non_null with typed loop param",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 2, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_ref_non_null_branch_copy_lowering(instrs, 2U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge does not mutate no-copy loop-target br_on_cast with typed loop param" {
  let trace : Array[String] = []
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref_type = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([any_ref_type], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([any_ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_cast(
                  @lib.LabelIdx::new(0U),
                  true,
                  any_heap,
                  false,
                  i31_heap,
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected loop-target br_on_cast raw ssa-nomerge success, got \{err}",
      )
  }

  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("hot-lift-error") }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_cast_proxy(instrs, false),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing loop-target br_on_cast with typed loop param" {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref_type = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([any_ref_type], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([any_ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_cast(
                  @lib.LabelIdx::new(0U),
                  true,
                  any_heap,
                  false,
                  i31_heap,
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "copy-needing loop-target br_on_cast with typed loop param",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 2U, true),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge preserves no-copy br_on_cast_fail on raw path" {
  let trace : Array[String] = []
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref_type = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([any_ref_type], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(any_ref_type),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32::new(7)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_cast_fail(
                  @lib.LabelIdx::new(0U),
                  true,
                  any_heap,
                  false,
                  i31_heap,
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(any_heap),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32::new(1)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected br_on_cast_fail raw ssa-nomerge success, got \{err}")
  }

  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("hot-lift-error") }),
    msg=trace.join("\n"),
  )
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(
    ssa_test_has_ssa_temp_local_writes(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites br_on_cast_fail taken-edge copies after divergent aliases" {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref_type = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([any_ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(any_ref_type),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_cast_fail(
                  @lib.LabelIdx::new(0U),
                  true,
                  any_heap,
                  false,
                  i31_heap,
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(any_heap),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "br_on_cast_fail taken-edge copies after divergent aliases",
  )
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 2U, false),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites multi-result br_on_cast_fail taken-edge copies" {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref_type = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([any_ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32(), any_ref_type]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::i32_const(@lib.I32::new(99)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_cast_fail(
                  @lib.LabelIdx::new(0U),
                  true,
                  any_heap,
                  false,
                  i31_heap,
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                @lib.Instruction::i32_const(@lib.I32::new(42)),
                @lib.Instruction::ref_i31(),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "multi-result br_on_cast_fail taken-edge copies",
  )
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 2U, false),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge does not mutate no-copy loop-target br_on_cast_fail with typed loop param" {
  let trace : Array[String] = []
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref_type = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([any_ref_type], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([any_ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_cast_fail(
                  @lib.LabelIdx::new(0U),
                  true,
                  any_heap,
                  false,
                  i31_heap,
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected loop-target br_on_cast_fail raw ssa-nomerge success, got \{err}",
      )
  }

  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("hot-lift-error") }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_loop_param_cast_proxy(instrs, true),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites copy-needing loop-target br_on_cast_fail with typed loop param" {
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let any_ref_type = @lib.ValType::ref_type(@lib.RefType::new(true, any_heap))
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([any_ref_type], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([any_ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::loop_(
              @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
              @lib.Expr::new([
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_cast_fail(
                  @lib.LabelIdx::new(0U),
                  true,
                  any_heap,
                  false,
                  i31_heap,
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "copy-needing loop-target br_on_cast_fail with typed loop param",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 2U, false),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites br_on_non_null taken-edge copies after divergent aliases" {
  let ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let non_null_ref_type = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(1U)]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(non_null_ref_type),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "br_on_non_null taken-edge copies after divergent aliases",
  )
  let (_, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(
    ssa_test_instrs_have_ref_non_null_branch_copy_lowering(instrs, 2U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites br_on_null taken-edge copies after divergent aliases" {
  let ref_type = @lib.ValType::ref_null(
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([ref_type, @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "br_on_null taken-edge copies after divergent aliases",
  )
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(
    ssa_test_instrs_have_ref_null_branch_copy_lowering(instrs, 2U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites local-tee-tested br_on_null block-exit copies" {
  let struct_idx = @lib.TypeIdx::new(0U)
  let struct_heap = @lib.HeapType::new(struct_idx)
  let nullable_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, struct_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_struct_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "local-tee-tested br_on_null block-exit copies",
  )
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(
    ssa_test_instrs_have_ref_null_branch_copy_lowering(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites local-tee-tested br_on_non_null block-exit copies" {
  let struct_idx = @lib.TypeIdx::new(0U)
  let struct_heap = @lib.HeapType::new(struct_idx)
  let nullable_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, struct_heap),
  )
  let non_null_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, struct_heap),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_struct_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(non_null_struct_ref),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::struct_new_default(struct_idx),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "local-tee-tested br_on_non_null block-exit copies",
  )
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(
    ssa_test_instrs_have_ref_non_null_branch_copy_lowering(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites ref-i31-tested br_on_null block-exit copies" {
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_i31(),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "ref-i31-tested br_on_null block-exit copies",
  )
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(
    ssa_test_instrs_have_ref_null_branch_copy_lowering(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites ref-i31-tested br_on_non_null block-exit copies" {
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i31ref()),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_i31(),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::ref_i31(),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "ref-i31-tested br_on_non_null block-exit copies",
  )
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(
    ssa_test_instrs_have_ref_non_null_branch_copy_lowering(instrs, 1U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge preserves ref-i31-to-eq br_on_non_null block-exit copies" {
  let non_null_eq_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(1U))
  block_body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::ref_i31(),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(non_null_eq_ref),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 1U, true, "ref-i31-to-eq br_on_non_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves struct-child-to-parent br_on_non_null block-exit copies" {
  let parent_idx = @lib.TypeIdx::new(0U)
  let child_idx = @lib.TypeIdx::new(1U)
  let parent_heap = @lib.HeapType::new(parent_idx)
  let non_null_parent_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, parent_heap),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(0U))
  block_body.append([
    @lib.Instruction::struct_new_default(child_idx),
    @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::struct_new_default(parent_idx),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(false, [parent_idx], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(non_null_parent_ref),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 0U, true, "struct-child-to-parent br_on_non_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves array-child-to-parent br_on_non_null block-exit copies" {
  let parent_idx = @lib.TypeIdx::new(0U)
  let child_idx = @lib.TypeIdx::new(1U)
  let parent_heap = @lib.HeapType::new(parent_idx)
  let array_field = @lib.FieldType::new(
    @lib.StorageType::val_type(@lib.ValType::i32()),
    @lib.Mut::var_(),
  )
  let non_null_parent_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, parent_heap),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(0U))
  block_body.append([
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::array_new_default(child_idx),
    @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::array_new_default(parent_idx),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::array(array_field)),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [parent_idx],
            @lib.CompType::array(array_field),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(non_null_parent_ref),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 0U, true, "array-child-to-parent br_on_non_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves ref-func-child-to-parent br_on_non_null block-exit copies" {
  let parent_idx = @lib.TypeIdx::new(0U)
  let child_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let callee_idx = @lib.FuncIdx::new(1U)
  let parent_heap = @lib.HeapType::new(parent_idx)
  let non_null_parent_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, parent_heap),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(0U))
  block_body.append([
    @lib.Instruction::ref_func(callee_idx),
    @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::ref_func(callee_idx),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::func([], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(false, [parent_idx], @lib.CompType::func([], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx, child_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([callee_idx]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(non_null_parent_ref),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          ]),
        ),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 0U, true, "ref-func-child-to-parent br_on_non_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves ref-i31-to-eq br_on_null prefix block-exit copies" {
  let nullable_eq_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(2U))
  block_body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::ref_i31(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::ref_i31(),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), nullable_eq_ref], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(nullable_eq_ref),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 2U, false, "ref-i31-to-eq br_on_null prefix block-exit copies",
  )
}

///|
test "ssa-nomerge preserves struct-child-to-parent br_on_null prefix block-exit copies" {
  let parent_idx = @lib.TypeIdx::new(0U)
  let child_idx = @lib.TypeIdx::new(1U)
  let parent_heap = @lib.HeapType::new(parent_idx)
  let nullable_eq_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
  )
  let nullable_parent_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, parent_heap),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(1U))
  block_body.append([
    @lib.Instruction::struct_new_default(child_idx),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::struct_new_default(parent_idx),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(false, [parent_idx], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_eq_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(nullable_parent_ref),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 1U, false, "struct-child-to-parent br_on_null prefix block-exit copies",
  )
}

///|
test "ssa-nomerge preserves array-child-to-parent br_on_null prefix block-exit copies" {
  let parent_idx = @lib.TypeIdx::new(0U)
  let child_idx = @lib.TypeIdx::new(1U)
  let parent_heap = @lib.HeapType::new(parent_idx)
  let array_field = @lib.FieldType::new(
    @lib.StorageType::val_type(@lib.ValType::i32()),
    @lib.Mut::var_(),
  )
  let nullable_eq_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
  )
  let nullable_parent_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, parent_heap),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(1U))
  block_body.append([
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::array_new_default(child_idx),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::array_new_default(parent_idx),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::array(array_field)),
        ),
        @lib.RecType::new(
          @lib.SubType::new(
            false,
            [parent_idx],
            @lib.CompType::array(array_field),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_eq_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(nullable_parent_ref),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 1U, false, "array-child-to-parent br_on_null prefix block-exit copies",
  )
}

///|
test "ssa-nomerge preserves ref-func-child-to-parent br_on_null prefix block-exit copies" {
  let parent_idx = @lib.TypeIdx::new(0U)
  let child_idx = @lib.TypeIdx::new(1U)
  let test_type_idx = @lib.TypeIdx::new(2U)
  let callee_idx = @lib.FuncIdx::new(1U)
  let parent_heap = @lib.HeapType::new(parent_idx)
  let nullable_eq_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
  )
  let nullable_parent_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, parent_heap),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(1U))
  block_body.append([
    @lib.Instruction::ref_func(callee_idx),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::ref_func(callee_idx),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::func([], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::new(false, [parent_idx], @lib.CompType::func([], [])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_eq_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx, child_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([callee_idx]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(nullable_parent_ref),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 1U, false, "ref-func-child-to-parent br_on_null prefix block-exit copies",
  )
}

///|
test "ssa-nomerge rewrites struct-new-default-tested br_on_null block-exit copies" {
  let struct_idx = @lib.TypeIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                  ]),
                ),
                @lib.Instruction::struct_new_default(struct_idx),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
              ]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "struct-new-default-tested br_on_null block-exit copies",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_ref_null_branch_copy_lowering(instrs, 0U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge rewrites struct-new-default-tested br_on_non_null block-exit copies" {
  let struct_idx = @lib.TypeIdx::new(0U)
  let struct_heap = @lib.HeapType::new(struct_idx)
  let non_null_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, struct_heap, exact=true),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(non_null_struct_ref),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::i32_const(@lib.I32::new(7)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                  ],
                  Some([
                    @lib.Instruction::i32_const(@lib.I32::new(8)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                  ]),
                ),
                @lib.Instruction::struct_new_default(struct_idx),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::i32_const(@lib.I32::new(9)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                @lib.Instruction::struct_new_default(struct_idx),
              ]),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          ]),
        ),
      ]),
    )
  let optimized = ssa_test_module_expected_mutation_valid(
    input, "struct-new-default-tested br_on_non_null block-exit copies",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(locals.length() > 1, msg=locals.to_string())
  assert_true(
    ssa_test_instrs_have_ref_non_null_branch_copy_lowering(instrs, 0U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge preserves array-new-default-tested br_on_null block-exit copies" {
  let array_idx = @lib.TypeIdx::new(0U)
  let array_field = @lib.FieldType::new(
    @lib.StorageType::val_type(@lib.ValType::i32()),
    @lib.Mut::var_(),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(0U))
  block_body.append([
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::array_new_default(array_idx),
    @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::array(array_field)),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 0U, false, "array-new-default-tested br_on_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves array-new-default-tested br_on_non_null block-exit copies" {
  let array_idx = @lib.TypeIdx::new(0U)
  let array_field = @lib.FieldType::new(
    @lib.StorageType::val_type(@lib.ValType::i32()),
    @lib.Mut::var_(),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(0U))
  block_body.append([
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::array_new_default(array_idx),
    @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::array_new_default(array_idx),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::array(array_field)),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(
                @lib.ValType::ref_array_nonnull(array_idx),
              ),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 0U, true, "array-new-default-tested br_on_non_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves ref-func-tested br_on_null block-exit copies" {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let test_type_idx = @lib.TypeIdx::new(1U)
  let callee_idx = @lib.FuncIdx::new(1U)
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(0U))
  block_body.append([
    @lib.Instruction::ref_func(callee_idx),
    @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx, callee_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([callee_idx]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          ]),
        ),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 0U, false, "ref-func-tested br_on_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves ref-func-tested br_on_non_null block-exit copies" {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let test_type_idx = @lib.TypeIdx::new(1U)
  let callee_idx = @lib.FuncIdx::new(1U)
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(0U))
  block_body.append([
    @lib.Instruction::ref_func(callee_idx),
    @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::ref_func(callee_idx),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type_idx, callee_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([callee_idx]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::funcref()),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          ]),
        ),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 0U, true, "ref-func-tested br_on_non_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves ref-cast-tested br_on_null block-exit copies" {
  let struct_idx = @lib.TypeIdx::new(0U)
  let struct_heap = @lib.HeapType::new(struct_idx)
  let nullable_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, struct_heap),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(1U))
  block_body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::ref_cast(true, struct_heap),
    @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_struct_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 1U, false, "ref-cast-tested br_on_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves ref-cast-tested br_on_non_null block-exit copies" {
  let struct_idx = @lib.TypeIdx::new(0U)
  let struct_heap = @lib.HeapType::new(struct_idx)
  let nullable_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, struct_heap),
  )
  let non_null_struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, struct_heap),
  )
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(1U))
  block_body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::ref_cast(true, struct_heap),
    @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::struct_new_default(struct_idx),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_struct_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(non_null_struct_ref),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 1U, true, "ref-cast-tested br_on_non_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves any-convert-tested br_on_null block-exit copies" {
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(1U))
  block_body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::any_convert_extern(),
    @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::externref()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 1U, false, "any-convert-tested br_on_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves any-convert-tested br_on_non_null block-exit copies" {
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(1U))
  block_body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::any_convert_extern(),
    @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::any_convert_extern(),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::externref()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::anyref()),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 1U, true, "any-convert-tested br_on_non_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves extern-convert-tested br_on_null block-exit copies" {
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(1U))
  block_body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::extern_convert_any(),
    @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::anyref()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 1U, false, "extern-convert-tested br_on_null block-exit copies",
  )
}

///|
test "ssa-nomerge preserves extern-convert-tested br_on_non_null block-exit copies" {
  let block_body = ssa_test_divergent_i32_local_prefix(@lib.LocalIdx::new(1U))
  block_body.append([
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::extern_convert_any(),
    @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32::new(9)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::extern_convert_any(),
  ])
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::anyref()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::externref()),
              @lib.Expr::new(block_body),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    )
  try! ssa_test_assert_raw_ref_branch_copy_lowering(
    input, 1U, true, "extern-convert-tested br_on_non_null block-exit copies",
  )
}

///|
test "ssa-nomerge does not mutate no-copy block-target br_table on raw path" {
  let trace : Array[String] = []
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     block
    #|       i32.const 7
    #|       local.set 1
    #|       local.get 0
    #|       br_table 0 0
    #|     end
    #|     i32.const 1))
    #|
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected no-copy br_table raw ssa-nomerge success, got \{err}")
  }

  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::br_table(
          [@lib.LabelIdx::new(0U)],
          @lib.LabelIdx::new(0U),
        ),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "ssa-nomerge does not mutate no-copy loop-target br_if on raw path" {
  let trace : Array[String] = []
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     loop
    #|       i32.const 7
    #|       local.set 1
    #|       local.get 0
    #|       br_if 0
    #|     end
    #|     i32.const 1))
    #|
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected loop br_if raw ssa-nomerge success, got \{err}")
  }

  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "ssa-nomerge does not mutate no-copy loop-target br_table on raw path" {
  let trace : Array[String] = []
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     loop
    #|       i32.const 7
    #|       local.set 1
    #|       local.get 0
    #|       br_table 0 0
    #|     end
    #|     i32.const 1))
    #|
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected loop br_table raw ssa-nomerge success, got \{err}")
  }

  assert_true(
    trace.any(fn(line) {
      line.contains("pass[ssa-nomerge]:skip-raw reason=structured-local-writes")
    }),
    msg=trace.join("\n"),
  )
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::br_table(
          [@lib.LabelIdx::new(0U)],
          @lib.LabelIdx::new(0U),
        ),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "ssa-nomerge rewrites loop-carried reads for br_table backedges" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     loop
    #|       local.get 1
    #|       drop
    #|       i32.const 7
    #|       local.set 1
    #|       local.get 0
    #|       br_table 0 0
    #|     end
    #|     i32.const 1))
    #|
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    input, "loop-carried reads for br_table backedges",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::br_table(
          [@lib.LabelIdx::new(0U)],
          @lib.LabelIdx::new(0U),
        ),
      ]),
    ),
    @lib.Instruction::i32_const(@lib.I32(1)),
  ])
}

///|
test "ssa-nomerge rewrites void br_table with canonical merge copies" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     block
    #|       local.get 0
    #|       if
    #|         i32.const 7
    #|         local.set 1
    #|       else
    #|         i32.const 8
    #|         local.set 1
    #|       end
    #|       block
    #|         local.get 0
    #|         br_table 1 1
    #|       end
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1))
    #|
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    input, "void br_table with canonical merge copies",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
          ],
          Some([
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
          ]),
        ),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::br_table(
              [@lib.LabelIdx::new(1U)],
              @lib.LabelIdx::new(1U),
            ),
          ]),
        ),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
}

///|
test "ssa-nomerge rewrites result br_table with canonical merge copies" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     block (result i32)
    #|       local.get 0
    #|       if
    #|         i32.const 7
    #|         local.set 1
    #|       else
    #|         i32.const 8
    #|         local.set 1
    #|       end
    #|       block
    #|         i32.const 42
    #|         local.get 0
    #|         br_table 1 1
    #|       end
    #|       i32.const 9
    #|       local.set 1
    #|       i32.const 10
    #|     end
    #|     drop
    #|     local.get 1))
    #|
  let optimized = ssa_test_pipeline_expected_mutation_valid(
    input, "result br_table with canonical merge copies",
  )
  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
          ],
          Some([
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
          ]),
        ),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(42)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::br_table(
              [@lib.LabelIdx::new(1U)],
              @lib.LabelIdx::new(1U),
            ),
          ]),
        ),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_const(@lib.I32(10)),
      ]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
}

///|
test "ssa-nomerge preserves no-copy result block br_if" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     i32.const 1
    #|     local.set 1
    #|     block (result i32)
    #|       i32.const 7
    #|       local.get 0
    #|       br_if 0
    #|       drop
    #|       i32.const 9
    #|     end))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected no-copy result br_if raw ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(9)),
      ]),
    ),
  ])
}

///|
test "ssa-nomerge rewrites structured branch merges with result-typed ifs" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     i32.const 0
    #|     local.set 1
    #|     local.get 0
    #|     if (result i32)
    #|       i32.const 1
    #|       local.set 1
    #|       i32.const 7
    #|     else
    #|       i32.const 2
    #|       local.set 1
    #|       i32.const 9
    #|     end
    #|     drop
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected structured merge raw ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_const(@lib.I32(7)),
      ],
      Some([
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_const(@lib.I32(9)),
      ]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
}

///|
test "ssa-nomerge keeps canonical param slots across typed if branch merges" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     local.get 0
    #|     if (result i32)
    #|       i32.const 7
    #|       local.set 0
    #|       i32.const 1
    #|     else
    #|       i32.const 9
    #|       local.set 0
    #|       i32.const 2
    #|     end
    #|     drop
    #|     local.get 0))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected typed-if param merge raw ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
      ],
      Some([
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
      ]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
}

///|
test "ssa-nomerge preserves unreachable compare carriers from func 523 shape" {
  let input =
    #| (module
    #|   (func (param i64) (result i32) (local i32 i64)
    #|     i32.const 7
    #|     local.set 1
    #|     block (result i64)
    #|       block
    #|         local.get 0
    #|         i64.const 1
    #|         i64.eq
    #|         if
    #|           i64.const 4
    #|           local.set 2
    #|           br 1
    #|         else
    #|           i32.const 0
    #|           return
    #|         end
    #|         unreachable
    #|       end
    #|       local.get 2
    #|     end
    #|     i64.const 0
    #|     i64.eq
    #|     if (result i32)
    #|       i32.const 1
    #|     else
    #|       local.get 2
    #|       i64.const 0
    #|       i64.gt_u
    #|     end))
    #|
  match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected func 523 followup compare carrier shape to survive ssa-nomerge, got \{err}",
      )
  }
}

///|
test "ssa-nomerge hot path preserves temp locals for unreachable dead tees" {
  let input =
    #| (module
    #|   (func (result i32)
    #|     (local i32)
    #|     block
    #|       unreachable
    #|     end
    #|     i32.const 7
    #|     local.tee 0
    #|     drop
    #|     i32.const 9))
    #|
  let optimized = match ssa_test_run_hot_path_only(input) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected unreachable dead tee hot-path success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(9)),
  ])
}

///|
test "ssa-nomerge preserves unreachable dead tee temps before later control" {
  let input =
    #| (module
    #|   (func (param i32)
    #|     block
    #|       i32.const 1
    #|       br_table 0 0
    #|     end
    #|     block
    #|       unreachable
    #|     end
    #|     i32.const 7
    #|     local.tee 0
    #|     drop
    #|     block (result i32)
    #|       i32.const 1
    #|     end
    #|     drop
    #|     local.get 0
    #|     drop
    #|     block
    #|       i32.const 1
    #|       br_if 0
    #|     end
    #|     loop
    #|       i32.const 1
    #|       br_if 0
    #|     end
    #|     i32.const 1
    #|     if
    #|       block
    #|         br 0
    #|       end
    #|     else
    #|       nop
    #|     end))
    #|
  let optimized = match ssa_test_run_hot_path_only(input) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected unreachable dead tee temp preservation before later control, got \{err}",
      )
  }

  let (locals, _) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
}

///|
test "ssa-nomerge keeps canonical locals for if-result unreachable tee carriers" {
  let input =
    #| (module
    #|   (func (param f64 i32) (result i32)
    #|     block
    #|       i32.const 1
    #|       br_table 0 0
    #|     end
    #|     block
    #|       unreachable
    #|     end
    #|     i32.const 7
    #|     local.tee 1
    #|     drop
    #|     i32.const 11
    #|     i32.const 22
    #|     i32.const 1
    #|     select (result i32)
    #|     drop
    #|     i32.const 1
    #|     if (result i32)
    #|       i32.const 4
    #|     else
    #|       i32.const 58
    #|     end
    #|     drop
    #|     local.get 1
    #|     drop
    #|     block
    #|       i32.const 1
    #|       br_if 0
    #|     end
    #|     loop
    #|       i32.const 0
    #|       br_if 0
    #|     end
    #|     i32.const 0
    #|     if
    #|       block
    #|         br 0
    #|       end
    #|     else
    #|       nop
    #|     end
    #|     i32.const 869))
    #|
  let optimized = match ssa_test_run_hot_path_only(input) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected if-result unreachable tee-carrier success, got \{err}")
  }

  let (locals, _) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
}

///|
test "ssa-nomerge keeps canonical locals when unreachable reads stay behind later control blocks" {
  let input =
    #| (module
    #|   (func (result i32)
    #|     (local i32)
    #|     block
    #|       unreachable
    #|     end
    #|     i32.const 7
    #|     local.tee 0
    #|     drop
    #|     block
    #|       i32.const 1
    #|       br_if 0
    #|     end
    #|     loop
    #|       i32.const 1
    #|       br_if 0
    #|     end
    #|     i32.const 1
    #|     if
    #|       block
    #|         br 0
    #|       end
    #|     else
    #|       nop
    #|     end
    #|     local.get 0))
    #|
  let optimized = match ssa_test_run_hot_path_only(input) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected structured unreachable tee-carrier hot-path success, got \{err}",
      )
  }

  let (locals, _) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
}

///|
test "ssa-nomerge hot path validates unreachable default-local carrier followup" {
  let input =
    #| (module
    #|   (func (param i64 i64 i64) (result i64)
    #|     (local i64 i64 i64
    #|       i32 i32 i32 i32 i32 i32 i32 i32 i32 i32
    #|       i32 i32 i32 i32 i32 i32 i32 i32 i32 i32
    #|       i32 i32 i32 i32 i32 i32 i32 i32 i32 i32
    #|       i32 i32 i32 i32 i32 i32 i32 i32 i32 i32
    #|       i32 i32 i32 i32 i32 i32 i32 i32 i32 i32
    #|       i32 i32 i32 i32 i32 i32 i32 i32 i32 i32
    #|       i32 i32 i32 i32 i32)
    #|     i64.const 9
    #|     local.set 5
    #|     local.get 5
    #|     drop
    #|     block (result i64)
    #|       block
    #|         local.get 0
    #|         i64.const 1
    #|         i64.eq
    #|         if
    #|           i64.const 4
    #|           local.set 3
    #|           br 1
    #|         else
    #|           i64.const 0
    #|           return
    #|         end
    #|         unreachable
    #|       end
    #|       local.get 3
    #|     end
    #|     i64.const 0
    #|     i64.eq
    #|     if (result i32)
    #|       i32.const 1
    #|     else
    #|       local.get 4
    #|       local.get 2
    #|       i64.gt_u
    #|     end
    #|     drop
    #|     local.get 1
    #|     local.get 4
    #|     i64.or))
    #|
  match ssa_test_run_hot_path_only(input) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected hot-path-only ssa-nomerge carrier followup to validate, got \{err}",
      )
  }
}
