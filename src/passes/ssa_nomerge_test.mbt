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
      @lib.Loop(@lib.VoidBlockType, @lib.Expr(loop_body)) =>
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
      @lib.Block(_, @lib.Expr(body)) | @lib.TryTable(_, _, @lib.Expr(body)) =>
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
fn ssa_test_nested_cfg_pipeline_fail_closed(source : String) -> Unit raise {
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
        "expected nested-CFG-sensitive ssa-nomerge fail-closed success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
}

///|
fn ssa_test_nested_cfg_hot_fail_closed(source : String) -> Unit raise {
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
fn ssa_test_typed_loop_param_module_fail_closed(
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
        "expected typed-loop-param ssa-nomerge fail-closed success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) { line.contains("pass[ssa-nomerge]:mutated") }),
    msg=trace.join("\n"),
  )
}

///|
fn ssa_test_typed_loop_param_pipeline_fail_closed(
  source : String,
) -> Unit raise {
  ssa_test_typed_loop_param_module_fail_closed(
    pass_test_module_from_wat(source),
  )
}

///|
fn ssa_test_typed_loop_param_hot_fail_closed(source : String) -> Unit raise {
  let mod_ = pass_test_module_from_wat(source)
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  @ir.hot_verify_all_or_abort(func)
  ssa_test_hot_func_typed_loop_param_fail_closed(func)
}

///|
fn ssa_test_hot_func_typed_loop_param_fail_closed(
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
fn ssa_test_hot_func_exceptional_fail_closed(func : @ir.HotFunc) -> Unit raise {
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
test "ssa-nomerge does not mutate exceptional-flow functions" {
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
        "expected exceptional-flow ssa-nomerge fail-closed success, got \{err}",
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
  ssa_test_hot_func_exceptional_fail_closed(func)
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
test "ssa-nomerge keeps multi-result typed loop-param direct br fail-closed" {
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
  ssa_test_typed_loop_param_pipeline_fail_closed(source)
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
test "ssa-nomerge keeps branch-bearing nested loops under typed loop params fail-closed" {
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
  ssa_test_typed_loop_param_pipeline_fail_closed(source)
}

///|
test "ssa-nomerge does not mutate typed loop-param control functions" {
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
  ssa_test_typed_loop_param_pipeline_fail_closed(source)
  ssa_test_typed_loop_param_hot_fail_closed(source)
  ignore(ssa_test_validate_ssa_nomerge_pipeline(source))
}

///|
test "ssa-nomerge preserves locals written before typed loop-param control" {
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
  ssa_test_typed_loop_param_pipeline_fail_closed(source)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
}

///|
test "ssa-nomerge keeps typed loop-param backedge values separate from body locals" {
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
  ssa_test_typed_loop_param_pipeline_fail_closed(source)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.const I32(100)"), msg=text)
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
}

///|
test "ssa-nomerge preserves typed loop-param control on the hot path" {
  // Multi-result typed loop-param control still stays fail-closed in the HOT
  // path; cover that boundary with a validated param-only typed-loop repro.
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
  ssa_test_typed_loop_param_hot_fail_closed(source)
  ssa_test_typed_loop_param_pipeline_fail_closed(source)
}

///|
test "ssa-nomerge preserves typed loop-carried induction values" {
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
  ssa_test_typed_loop_param_pipeline_fail_closed(source)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("local.tee"), msg=text)
  assert_true(text.contains("i32.shl"), msg=text)
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
test "ssa-nomerge still skips nested result-if with branch in condition block" {
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
  ssa_test_nested_cfg_pipeline_fail_closed(source)
  ssa_test_nested_cfg_hot_fail_closed(source)
}

///|
test "ssa-nomerge still skips nested result-if with br_if in condition block" {
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
  ssa_test_nested_cfg_pipeline_fail_closed(source)
  ssa_test_nested_cfg_hot_fail_closed(source)
}

///|
test "ssa-nomerge still skips nested result-if with nested loop in condition block" {
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
  ssa_test_nested_cfg_pipeline_fail_closed(source)
  ssa_test_nested_cfg_hot_fail_closed(source)
}

///|
test "ssa-nomerge still skips nested result-if with non-i32 condition block result" {
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
    msg="non-i32 condition block must stay fail-closed",
  )
  ssa_test_hot_func_ssa_nomerge_revision_unchanged(func)
}

///|
test "ssa-nomerge still skips nested result-if with branch in condition" {
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
    msg="branch in condition must stay fail-closed",
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
test "ssa-nomerge still skips nested result-if with branch in arm value-block" {
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
  ssa_test_nested_cfg_pipeline_fail_closed(source)
  ssa_test_nested_cfg_hot_fail_closed(source)
}

///|
test "ssa-nomerge still skips nested result-if with br_if in arm value-block" {
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
  ssa_test_nested_cfg_pipeline_fail_closed(source)
  ssa_test_nested_cfg_hot_fail_closed(source)
}

///|
test "ssa-nomerge still skips nested result-if with nested if in arm value-block" {
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
  ssa_test_nested_cfg_pipeline_fail_closed(source)
  ssa_test_nested_cfg_hot_fail_closed(source)
}

///|
test "ssa-nomerge still skips nested result-if with nested loop in arm value-block" {
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
  ssa_test_nested_cfg_pipeline_fail_closed(source)
  ssa_test_nested_cfg_hot_fail_closed(source)
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
    msg="value-producing mixed-arm prefix must stay fail-closed",
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
    msg="roots after final mixed-arm value block must stay fail-closed",
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
    msg="two mixed-arm value blocks must stay fail-closed",
  )
  ssa_test_hot_func_ssa_nomerge_revision_unchanged(func)
}

///|
test "ssa-nomerge still skips mixed arm with branch in final value-block" {
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
    msg="branch inside mixed-arm final value block must stay fail-closed",
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
    msg="mixed arm value-block result type mismatch must stay fail-closed",
  )
  ssa_test_hot_func_ssa_nomerge_revision_unchanged(func)
}

///|
test "ssa-nomerge still skips mixed arm with nested block inside final value-block" {
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
  ssa_test_nested_cfg_pipeline_fail_closed(source)
  ssa_test_nested_cfg_hot_fail_closed(source)
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
    msg="arm value-block result type mismatch must stay fail-closed",
  )
  ssa_test_hot_func_ssa_nomerge_revision_unchanged(func)
}

///|
test "ssa-nomerge still skips nested result-if with nested if in condition" {
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
  ssa_test_nested_cfg_pipeline_fail_closed(source)
  ssa_test_nested_cfg_hot_fail_closed(source)
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
test "ssa-nomerge still skips nested result-if with multi-value result" {
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
  ssa_test_nested_cfg_pipeline_fail_closed(source)
  ssa_test_nested_cfg_hot_fail_closed(source)
}

///|
test "ssa-nomerge still skips nested result-if with br" {
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
  ssa_test_nested_cfg_pipeline_fail_closed(source)
  ssa_test_nested_cfg_hot_fail_closed(source)
}

///|
test "ssa-nomerge still skips nested result-if with br_if" {
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
  ssa_test_nested_cfg_pipeline_fail_closed(source)
  ssa_test_nested_cfg_hot_fail_closed(source)
}

///|
test "ssa-nomerge still skips nested result-if with nested loop" {
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
  ssa_test_nested_cfg_pipeline_fail_closed(source)
  ssa_test_nested_cfg_hot_fail_closed(source)
}

///|
test "ssa-nomerge still skips nested result-if with nested if" {
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
  ssa_test_nested_cfg_pipeline_fail_closed(source)
  ssa_test_nested_cfg_hot_fail_closed(source)
}

///|
test "ssa-nomerge still skips nested result if under value block" {
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
  ssa_test_nested_cfg_pipeline_fail_closed(source)
  ssa_test_nested_cfg_hot_fail_closed(source)
  ssa_test_nested_cfg_hot_local_traffic_preserved(source)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
}

///|
test "ssa-nomerge still skips nested value block with br" {
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
  ssa_test_nested_cfg_pipeline_fail_closed(source)
  ssa_test_nested_cfg_hot_fail_closed(source)
  let optimized = ssa_test_validate_ssa_nomerge_pipeline(source)
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("local.set"), msg=text)
  assert_true(text.contains("local.get"), msg=text)
}

///|
test "ssa-nomerge still skips nested value block with br_if" {
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
  ssa_test_nested_cfg_pipeline_fail_closed(source)
  ssa_test_nested_cfg_hot_fail_closed(source)
}

///|
test "ssa-nomerge still skips nested loop under value block" {
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
  ssa_test_nested_cfg_pipeline_fail_closed(source)
  ssa_test_nested_cfg_hot_fail_closed(source)
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
test "ssa-nomerge rewrites moderately large structured branch functions without hot fallback" {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      ssa_test_large_structured_branch_fixture(),
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
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
  match
    pass_test_run_pipeline(
      ssa_test_large_structured_local_write_fixture(130),
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
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
}

///|
test "ssa-nomerge keeps audited high-threshold structured local-write functions without branches on raw path" {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      ssa_test_large_structured_local_write_fixture(2047),
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
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
  match
    pass_test_run_pipeline(
      ssa_test_large_structured_branch_if_prefix_fixture(1020),
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
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
}

///|
test "ssa-nomerge keeps audited high-threshold structured branch functions on raw path" {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      ssa_test_large_structured_branch_if_prefix_fixture(2046),
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
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
test "ssa-nomerge keeps loop-carried locals canonical before br_if backedges" {
  let trace : Array[String] = []
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
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected loop-carried ssa-nomerge success, got \{err}")
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
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
          ]),
        ),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
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
test "ssa-nomerge preserves br_on_cast taken-edge copies after divergent aliases" {
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
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected br_on_cast copy raw ssa-nomerge success, got \{err}")
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
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 2U, true),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge preserves multi-result br_on_cast taken-edge copies" {
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
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected multi-result br_on_cast copy raw ssa-nomerge success, got \{err}",
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
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 2U, true),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge preserves no-copy loop-target br_on_non_null with typed loop param" {
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
test "ssa-nomerge preserves copy-needing loop-target br_on_non_null with typed loop param" {
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
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected copy-needing loop-target br_on_non_null raw ssa-nomerge success, got \{err}",
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
    ssa_test_instrs_have_ref_non_null_branch_copy_lowering(instrs, 2U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge preserves no-copy loop-target br_on_cast with typed loop param" {
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
test "ssa-nomerge preserves copy-needing loop-target br_on_cast with typed loop param" {
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
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected copy-needing loop-target br_on_cast raw ssa-nomerge success, got \{err}",
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
test "ssa-nomerge preserves br_on_cast_fail taken-edge copies after divergent aliases" {
  let trace : Array[String] = []
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
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected br_on_cast_fail copy raw ssa-nomerge success, got \{err}")
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
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 2U, false),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge preserves multi-result br_on_cast_fail taken-edge copies" {
  let trace : Array[String] = []
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
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected multi-result br_on_cast_fail copy raw ssa-nomerge success, got \{err}",
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
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 2U, false),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge preserves no-copy loop-target br_on_cast_fail with typed loop param" {
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
test "ssa-nomerge preserves copy-needing loop-target br_on_cast_fail with typed loop param" {
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
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected copy-needing loop-target br_on_cast_fail raw ssa-nomerge success, got \{err}",
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
    ssa_test_instrs_have_ref_cast_branch_copy_block(instrs, 2U, false),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge preserves br_on_non_null taken-edge copies after divergent aliases" {
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
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected br_on_non_null copy raw ssa-nomerge success, got \{err}")
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
  let (_, instrs) = try! ssa_test_defined_func(optimized, 1)
  assert_true(
    ssa_test_instrs_have_ref_non_null_branch_copy_lowering(instrs, 2U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge preserves br_on_null taken-edge copies after divergent aliases" {
  let trace : Array[String] = []
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
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected br_on_null copy raw ssa-nomerge success, got \{err}")
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
  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  assert_true(
    ssa_test_instrs_have_ref_null_branch_copy_lowering(instrs, 2U),
    msg=instrs.to_string(),
  )
}

///|
test "ssa-nomerge preserves no-copy block-target br_table on raw path" {
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
test "ssa-nomerge preserves no-copy loop-target br_if on raw path" {
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
test "ssa-nomerge preserves no-copy loop-target br_table on raw path" {
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
test "ssa-nomerge preserves loop-carried reads for br_table backedges" {
  let trace : Array[String] = []
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
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected loop-carried br_table ssa-nomerge success, got \{err}")
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
test "ssa-nomerge preserves void br_table with canonical merge copies" {
  let trace : Array[String] = []
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
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected copy br_table raw ssa-nomerge success, got \{err}")
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
test "ssa-nomerge preserves result br_table with canonical merge copies" {
  let trace : Array[String] = []
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
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected result br_table raw ssa-nomerge success, got \{err}")
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
test "ssa-nomerge hot path preserves Binaryen temp locals for unreachable dead tees" {
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
