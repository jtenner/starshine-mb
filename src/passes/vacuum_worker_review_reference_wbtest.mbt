// Exact pre-change worker scheduling control for the dedicated performance lane.

///|
fn vacuum_worker_review_reference(
  instrs : Array[@lib.Instruction],
  module_ctx : @ir.HotModuleContext?,
) -> (Array[@lib.Instruction], Bool) {
  let rewritten : Array[@lib.Instruction] = []
  let mut changed = false
  let mut idx = 0
  let mut prev_may_fallthrough = true
  while idx < instrs.length() {
    if !prev_may_fallthrough {
      changed = true
      break
    }
    match
      run_hot_pipeline_raw_vacuum_dropped_pure_multivalue_width_at(
        instrs, idx, module_ctx,
      ) {
      Some(width) => {
        idx += width
        changed = true
        continue
      }
      None => ()
    }
    if idx + 3 < instrs.length() {
      match (instrs[idx], instrs[idx + 1], instrs[idx + 2], instrs[idx + 3]) {
        (
          @lib.I32Const(_),
          @lib.I32Const(@lib.I32(length)),
          @lib.ArrayNew(_),
          @lib.Drop,
        ) if length >= 0 => {
          idx += 4
          changed = true
          continue
        }
        _ => ()
      }
    }
    if idx + 2 < instrs.length() {
      match (instrs[idx], instrs[idx + 1], instrs[idx + 2]) {
        (@lib.I32Const(@lib.I32(length)), @lib.ArrayNewDefault(_), @lib.Drop) if length >=
          0 => {
          idx += 3
          changed = true
          continue
        }
        _ => ()
      }
    }
    match
      run_hot_pipeline_raw_vacuum_dropped_simple_struct_length_at(
        instrs, idx, module_ctx,
      ) {
      Some(length) => {
        idx += length
        changed = true
        continue
      }
      None => ()
    }
    if run_hot_pipeline_raw_vacuum_dropped_ref_func_struct_at(
        instrs, idx, module_ctx,
      ) {
      idx += 3
      changed = true
      continue
    }
    match
      run_hot_pipeline_raw_vacuum_fresh_array_set_replacement_at(
        instrs, idx, module_ctx,
      ) {
      Some(replacement) => {
        for instr in replacement {
          rewritten.push(instr)
        }
        idx += 5
        changed = true
        continue
      }
      None => ()
    }
    if idx + 5 < instrs.length() &&
      instrs[idx] == instrs[idx + 3] &&
      instrs[idx + 1] == instrs[idx + 4] &&
      instrs[idx + 2] == @lib.Instruction::drop() &&
      instrs[idx + 5] == @lib.Instruction::drop() &&
      instrs[idx] is @lib.LocalGet(_) &&
      run_hot_pipeline_raw_vacuum_instr_is_idempotent_scalar_load(
        instrs[idx + 1],
      ) {
      let address = instrs[idx]
      let load = instrs[idx + 1]
      rewritten.push(address)
      rewritten.push(load)
      rewritten.push(@lib.Instruction::drop())
      idx += 6
      while idx + 2 < instrs.length() &&
            instrs[idx] == address &&
            instrs[idx + 1] == load &&
            instrs[idx + 2] == @lib.Instruction::drop() {
        idx += 3
      }
      changed = true
      continue
    }
    let instr = instrs[idx]
    match instr {
      @lib.Nop => {
        changed = true
        idx = idx + 1
        continue
      }
      @lib.Block(block_type, @lib.Expr(body)) => {
        if block_type != @lib.BlockType::void_() &&
          idx + 1 < instrs.length() &&
          instrs[idx + 1] is @lib.Drop &&
          (
            run_hot_pipeline_raw_vacuum_body_has_only_pure_self_branch(body) ||
            run_hot_pipeline_raw_vacuum_body_has_only_pure_outer_branch_wrapper(
              body,
            )
          ) {
          match
            run_hot_pipeline_raw_vacuum_dropped_control_arities_at(
              instrs, idx, block_type, module_ctx,
            ) {
            Some((param_count, result_count)) => {
              // The parent has already evaluated the entry values. Keep their
              // effects and consume their stack lanes when the control is gone.
              for _ in 0..<param_count {
                rewritten.push(@lib.Instruction::drop())
              }
              changed = true
              idx += result_count + 1
              continue
            }
            None => ()
          }
        }
        if block_type == @lib.BlockType::void_() &&
          run_hot_pipeline_raw_vacuum_body_is_owner_targeted_no_throw_try_table(
            body,
          ) {
          match body[0] {
            @lib.TryTable(_, _, @lib.Expr(try_body)) => {
              let (next_try_body, _) = vacuum_worker_review_reference(
                try_body, module_ctx,
              )
              for next_instr in next_try_body {
                rewritten.push(next_instr)
              }
            }
            _ => ()
          }
          changed = true
          idx = idx + 1
          continue
        }
        match block_type {
          @lib.VoidBlockType =>
            match
              run_hot_pipeline_raw_vacuum_flatten_terminal_owner_branch(body) {
              Some(flattened) => {
                for next_instr in flattened {
                  rewritten.push(next_instr)
                }
                changed = true
                idx = idx + 1
                continue
              }
              None => ()
            }
          _ => ()
        }
        match block_type {
          @lib.VoidBlockType if body.length() == 0 &&
            (
              run_hot_pipeline_raw_vacuum_instrs_have_f1895_empty_sibling_at(
                instrs, idx,
              ) ||
              run_hot_pipeline_raw_vacuum_instrs_have_f2072_empty_sibling_at(
                instrs, idx,
              ) ||
              run_hot_pipeline_raw_vacuum_instrs_have_f2842_empty_block_before_live_if_at(
                instrs, idx,
              ) ||
              run_hot_pipeline_raw_vacuum_empty_block_before_local_copy_continuation(
                instrs, idx,
              )
            ) => {
            changed = true
            idx = idx + 1
            continue
          }
          @lib.VoidBlockType => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f5138_outer_singleton_parent(
                body, module_ctx,
              ) {
              Some(flattened) => {
                for next_instr in flattened {
                  rewritten.push(next_instr)
                }
                changed = true
                idx = idx + 1
                continue
              }
              None => ()
            }
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f364_four_field_child_before_continuation(
                body, module_ctx,
              ) {
              Some(next_body) => {
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(next_body)),
                )
                changed = true
                idx = idx + 1
                continue
              }
              None => ()
            }
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f364_four_field_singleton_child(
                body, module_ctx,
              ) {
              Some(next_body) => {
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(next_body)),
                )
                changed = true
                idx = idx + 1
                continue
              }
              None => ()
            }
          }
          _ => ()
        }
        match block_type {
          @lib.VoidBlockType if instrs.length() == 1 &&
            run_hot_pipeline_raw_vacuum_body_is_single_block_prefix_if_wrapper_candidate(
              body,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_is_predicate_local_continuation_preserve_candidate(
              body,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_is_local_set_leading_prefix_if_preserve_candidate(
              body,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_is_five_arg_allocator_release_prefix_if_preserve_candidate(
              body,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_is_f1346_local_set_release_prefix_if_preserve_candidate(
              body,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_is_f3469_const_arg_local_set_release_prefix_if_preserve_candidate(
              body,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_is_f5138_load_linked_result_prefix_parent_preserve_candidate(
              body,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_is_f5138_paired_result_prefix_parent_preserve_candidate(
              body,
            ) &&
            !run_hot_pipeline_raw_vacuum_instrs_contain_unreachable(body) &&
            !run_hot_pipeline_raw_vacuum_body_targets_owner(body, 0) => {
            let rebased = match
              run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(body, 0) {
              Some(rebased) => rebased
              None => {
                rewritten.push(instr)
                idx += 1
                continue
              }
            }
            let (clean_rebased, _) = vacuum_worker_review_reference(
              rebased, module_ctx,
            )
            for next_instr in clean_rebased {
              rewritten.push(next_instr)
            }
            changed = true
            idx = idx + 1
            continue
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_artifact_call_prefix_parent_unwrap_candidate(
              body,
            ) &&
            run_hot_pipeline_raw_vacuum_body_has_local_set_outer_br_continuation(
              instrs, idx,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_targets_owner(body, 0) => {
            let rebased = match
              run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(body, 0) {
              Some(rebased) => rebased
              None => {
                rewritten.push(instr)
                idx += 1
                continue
              }
            }
            for next_instr in rebased {
              rewritten.push(next_instr)
            }
            changed = true
            idx = idx + 1
            continue
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f4070_one_arg_prefix_parent_before_result_dispatch(
              body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f4070_one_arg_prefix_parent_before_result_dispatch(
                body,
              ) {
              Some(flattened) =>
                for next_instr in flattened {
                  rewritten.push(next_instr)
                }
              None => ()
            }
            changed = true
            idx = idx + 1
            continue
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f4915_tag1_owner_dispatch_before_tag95_return(
              body, instrs, idx,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f4915_tag1_owner_dispatch_before_tag95_return(
                body, instrs, idx,
              ) {
              Some(flattened) =>
                for next_instr in flattened {
                  rewritten.push(next_instr)
                }
              None => ()
            }
            changed = true
            idx = idx + 1
            continue
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f4859_leading_owner_exit_dispatch_before_case0_return(
              body, instrs, idx,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f4859_leading_owner_exit_dispatch_before_case0_return(
                body, instrs, idx,
              ) {
              Some(flattened) =>
                for next_instr in flattened {
                  rewritten.push(next_instr)
                }
              None => ()
            }
            changed = true
            idx = idx + 1
            continue
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f5288_leading_tag_dispatch_wrappers_before_returns(
              body, instrs, idx,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f5288_leading_tag_dispatch_wrappers_before_returns(
                body, instrs, idx,
              ) {
              Some(flattened) =>
                for next_instr in flattened {
                  rewritten.push(next_instr)
                }
              None => ()
            }
            changed = true
            idx = idx + 1
            continue
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f5392_leading_tag2_dispatch_wrappers_before_call_return(
              body, instrs, idx,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f5392_leading_tag2_dispatch_wrappers_before_call_return(
                body, instrs, idx,
              ) {
              Some(flattened) =>
                for next_instr in flattened {
                  rewritten.push(next_instr)
                }
              None => ()
            }
            changed = true
            idx = idx + 1
            continue
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_f5351_leading_tag_dispatch_before_zero_return(
              body, instrs, idx,
            ) => {
            let rebased = match
              run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(body, 0) {
              Some(rebased) => rebased
              None => {
                rewritten.push(instr)
                idx += 1
                continue
              }
            }
            let (clean_rebased, _) = vacuum_worker_review_reference(
              rebased, module_ctx,
            )
            for next_instr in clean_rebased {
              rewritten.push(next_instr)
            }
            changed = true
            idx = idx + 1
            continue
          }
          _ => ()
        }
        let (next_body, body_changed) = vacuum_worker_review_reference(
          body, module_ctx,
        )
        changed = changed || body_changed
        match block_type {
          @lib.VoidBlockType if next_body.length() == 0 &&
            run_hot_pipeline_raw_vacuum_empty_block_before_local_copy_continuation(
              instrs, idx,
            ) => changed = true
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_local_copy_child(
              next_body,
            ) &&
            run_hot_pipeline_raw_vacuum_has_f6286_f6594_f6628_f6785_f7095_f7130_f7133_f7138_f7141_f7263_parser_branch_continuation(
              instrs, idx,
            ) => {
            for next_instr in next_body {
              rewritten.push(next_instr)
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_f5154_retain_pair_result_before_slot_store_preserve_candidate(
              next_body, instrs, idx,
            ) ||
            run_hot_pipeline_raw_vacuum_body_is_f5184_single_retain_result_before_drop_continuation_preserve_candidate(
              next_body, instrs, idx,
            ) =>
            rewritten.push(
              @lib.Instruction::block(block_type, @lib.Expr::new(next_body)),
            )
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_f4493_offset4_call_result_tag1_prefix_before_allocation_return_preserve_candidate(
              next_body, instrs, idx,
            ) =>
            rewritten.push(
              @lib.Instruction::block(block_type, @lib.Expr::new(next_body)),
            )
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_f5032_two_release_prefix_if_parent_preserve_candidate(
              next_body,
            ) =>
            rewritten.push(
              @lib.Instruction::block(block_type, @lib.Expr::new(next_body)),
            )
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_f2094_increment_probe_prefix_before_block_continuation_preserve_candidate(
              next_body, instrs, idx,
            ) ||
            run_hot_pipeline_raw_vacuum_body_is_f2094_increment_probe_prefix_before_block_continuation_preserve_candidate(
              body, instrs, idx,
            ) =>
            rewritten.push(
              @lib.Instruction::block(block_type, @lib.Expr::new(next_body)),
            )
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f2850_local_copy_guard_wrapper(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f2850_local_copy_guard_wrapper(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f1738_loop_head_local_copy_child(
              next_body, instrs, idx,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f1738_loop_head_local_copy_child(
                next_body, instrs, idx,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f1743_loop_head_copy_before_nested_dispatch(
              next_body, instrs, idx,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f1743_loop_head_copy_before_nested_dispatch(
                next_body, instrs, idx,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f3579_loop_head_local_copy_guard_wrapper(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f3579_loop_head_local_copy_guard_wrapper(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f3841_tag_dispatch_singleton_child_before_local_set_branch(
              next_body, instrs, idx,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f3841_tag_dispatch_singleton_child_before_local_set_branch(
                next_body, instrs, idx,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f3998_tag2_prefix_child_before_loop_continuation(
              next_body, instrs, idx,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f3998_tag2_prefix_child_before_loop_continuation(
                next_body, instrs, idx,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f5419_tag1_singleton_owner_before_stream_loop(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f5419_tag1_singleton_owner_before_stream_loop(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f1963_local_set_sentinel_comparison_wrapper(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f1963_local_set_sentinel_comparison_wrapper(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f1948_call_tee_sentinel_branch_wrappers(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f1948_call_tee_sentinel_branch_wrappers(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f1946_loop_arg_copy_before_eqz_call(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f1946_loop_arg_copy_before_eqz_call(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f1054_local_copy_child_before_load_prefix(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f1054_local_copy_child_before_load_prefix(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f1148_tag_selection_wrappers_before_load_continuation(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f1148_tag_selection_wrappers_before_load_continuation(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f1167_br_table_child_before_unreachable(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f1167_br_table_child_before_unreachable(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f1940_call_tee_br_table_wrapper_before_unreachable(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f1940_call_tee_br_table_wrapper_before_unreachable(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f1956_call_tee_br_table_wrapper_before_unreachable(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f1956_call_tee_br_table_wrapper_before_unreachable(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f2054_call_tee_br_table_wrapper_before_unreachable(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f2054_call_tee_br_table_wrapper_before_unreachable(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f2321_call_arg_tee_br_table_release_ladder_wrapper_before_unreachable(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f2321_call_arg_tee_br_table_release_ladder_wrapper_before_unreachable(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f2334_tag236_wrapper_before_offset8_continuation(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f2334_tag236_wrapper_before_offset8_continuation(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f2651_load_br_table_wrapper_before_converter_continuation(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f2651_load_br_table_wrapper_before_converter_continuation(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f2696_tee_br_table_release_wrapper_before_unreachable(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f2696_tee_br_table_release_wrapper_before_unreachable(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f2714_direct_call_br_table_release_wrapper_before_local_set_continuation(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f2714_direct_call_br_table_release_wrapper_before_local_set_continuation(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f2905_direct_call_br_table_local_load_wrapper_before_call_continuation(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f2905_direct_call_br_table_local_load_wrapper_before_call_continuation(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f2775_call_tee_cleanup_return_if_wrapper_before_sibling_branch(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f2775_call_tee_cleanup_return_if_wrapper_before_sibling_branch(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f2823_call_tee_branch_cleanup_wrapper_before_i64_return(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f2823_call_tee_branch_cleanup_wrapper_before_i64_return(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f2297_call_tee_br_table_release_ladder_wrapper_before_unreachable(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f2297_call_tee_br_table_release_ladder_wrapper_before_unreachable(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f2320_call_tee_br_table_double_update_wrapper_before_unreachable(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f2320_call_tee_br_table_double_update_wrapper_before_unreachable(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f1792_br_table_dispatch_return_wrapper(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f1792_br_table_dispatch_return_wrapper(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f1836_loop_if_owner_branch_wrapper(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f1836_loop_if_owner_branch_wrapper(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_drop_f1895_empty_sibling(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_drop_f1895_empty_sibling(
                next_body,
              ) {
              Some(cleaned_body) =>
                rewritten.push(
                  @lib.Instruction::block(
                    block_type,
                    @lib.Expr::new(cleaned_body),
                  ),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_drop_f2072_empty_sibling(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_drop_f2072_empty_sibling(
                next_body,
              ) {
              Some(cleaned_body) =>
                rewritten.push(
                  @lib.Instruction::block(
                    block_type,
                    @lib.Expr::new(cleaned_body),
                  ),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_drop_f2842_empty_block_before_live_if(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_drop_f2842_empty_block_before_live_if(
                next_body,
              ) {
              Some(cleaned_body) =>
                rewritten.push(
                  @lib.Instruction::block(
                    block_type,
                    @lib.Expr::new(cleaned_body),
                  ),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f1155_single_release_child_before_branch_continuation(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f1155_single_release_child_before_branch_continuation(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f1260_tag_dispatch_child_before_append_update(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f1260_tag_dispatch_child_before_append_update(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f2130_tag42_tag43_loop_head_dispatch_wrapper(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f2130_tag42_tag43_loop_head_dispatch_wrapper(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_f649_branchy_loop_dispatch_parent_wrapper_candidate(
              next_body,
            ) => {
            let rebased = match
              run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(
                next_body, 0,
              ) {
              Some(rebased) => rebased
              None => {
                rewritten.push(instr)
                idx += 1
                continue
              }
            }
            for next_instr in rebased {
              rewritten.push(next_instr)
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_f749_double_branchy_selection_wrapper_candidate(
              next_body,
            ) &&
            run_hot_pipeline_raw_vacuum_has_f749_i64_return_continuation(
              instrs, idx,
            ) => {
            match next_body[0] {
              @lib.Block(@lib.VoidBlockType, @lib.Expr(child_body)) => {
                let rebased_once = match
                  run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(
                    child_body, 0,
                  ) {
                  Some(rebased) => rebased
                  None => {
                    rewritten.push(instr)
                    idx += 1
                    continue
                  }
                }
                let rebased_twice = match
                  run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(
                    rebased_once, 0,
                  ) {
                  Some(rebased) => rebased
                  None => {
                    rewritten.push(instr)
                    idx += 1
                    continue
                  }
                }
                for next_instr in rebased_twice {
                  rewritten.push(next_instr)
                }
              }
              _ => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_f749_branchy_selection(
              next_body,
            ) &&
            run_hot_pipeline_raw_vacuum_has_f749_i64_return_continuation(
              instrs, idx,
            ) => {
            let rebased = match
              run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(
                next_body, 0,
              ) {
              Some(rebased) => rebased
              None => {
                rewritten.push(instr)
                idx += 1
                continue
              }
            }
            for next_instr in rebased {
              rewritten.push(next_instr)
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_has_top_level_nop(
              body,
            ) &&
            run_hot_pipeline_raw_vacuum_body_is_branchy_loop_dispatch_singleton_wrapper_candidate(
              next_body,
            ) => {
            let rebased = match
              run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(
                next_body, 0,
              ) {
              Some(rebased) => rebased
              None => {
                rewritten.push(instr)
                idx += 1
                continue
              }
            }
            for next_instr in rebased {
              rewritten.push(next_instr)
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_empty_block_call_prefix_if_wrapper_candidate(
              next_body,
            ) &&
            !run_hot_pipeline_raw_vacuum_instrs_contain_unreachable(next_body) => {
            rewritten.push(
              @lib.Instruction::block(
                block_type,
                @lib.Expr::new(
                  run_hot_pipeline_raw_vacuum_drop_leading_empty_blocks(
                    next_body,
                  ),
                ),
              ),
            )
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f4463_offset12_indexed_singleton_owner(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f4463_offset12_indexed_singleton_owner(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if next_body.length() == 1 &&
            (match next_body[0] {
              @lib.Block(@lib.VoidBlockType, @lib.Expr(child_body)) =>
                (
                  (
                    run_hot_pipeline_raw_vacuum_body_is_if_wrapper_candidate(
                      child_body,
                    ) &&
                    run_hot_pipeline_raw_vacuum_body_has_call_prefix_before_final_if(
                      child_body,
                    ) &&
                    run_hot_pipeline_raw_vacuum_body_has_top_level_nop(body)
                  ) ||
                  run_hot_pipeline_raw_vacuum_body_is_refcount_call_prefix_if_wrapper_candidate(
                    child_body,
                  )
                ) &&
                !run_hot_pipeline_raw_vacuum_instrs_contain_unreachable(
                  child_body,
                ) &&
                !run_hot_pipeline_raw_vacuum_body_targets_owner(child_body, 0)
              _ => false
            }) => {
            match next_body[0] {
              @lib.Block(@lib.VoidBlockType, @lib.Expr(child_body)) =>
                rewritten.push(
                  @lib.Instruction::block(
                    block_type,
                    @lib.Expr::new(
                      match
                        run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(
                          child_body, 0,
                        ) {
                        Some(rebased) => rebased
                        None => {
                          rewritten.push(instr)
                          idx += 1
                          continue
                        }
                      },
                    ),
                  ),
                )
              _ => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_singleton_call_prefix_if_block(
              next_body,
            ) &&
            run_hot_pipeline_raw_vacuum_body_has_empty_block_call_prefix_shape_ignoring_nops(
              body,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_targets_owner(next_body, 0) => {
            let rebased = match
              run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(
                next_body, 0,
              ) {
              Some(rebased) => rebased
              None => {
                rewritten.push(instr)
                idx += 1
                continue
              }
            }
            for next_instr in rebased {
              rewritten.push(next_instr)
            }
            changed = true
          }
          @lib.VoidBlockType if body.length() == 1 &&
            next_body.length() == 1 &&
            (match next_body[0] {
              @lib.Block(@lib.VoidBlockType, @lib.Expr(protected_body)) =>
                run_hot_pipeline_raw_vacuum_body_is_local_set_leading_prefix_if_preserve_candidate(
                  protected_body,
                ) ||
                run_hot_pipeline_raw_vacuum_body_is_five_arg_allocator_release_prefix_if_preserve_candidate(
                  protected_body,
                ) ||
                run_hot_pipeline_raw_vacuum_body_is_two_arg_call_local_set_prefix_if_preserve_candidate(
                  protected_body,
                ) ||
                run_hot_pipeline_raw_vacuum_body_is_multi_local_prefix_parent_preserve_candidate(
                  protected_body,
                ) ||
                run_hot_pipeline_raw_vacuum_body_is_f5138_paired_result_prefix_parent_preserve_candidate(
                  protected_body,
                )
              _ => false
            }) &&
            !run_hot_pipeline_raw_vacuum_body_targets_owner(next_body, 0) => {
            let rebased = match
              run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(
                next_body, 0,
              ) {
              Some(rebased) => rebased
              None => {
                rewritten.push(instr)
                idx += 1
                continue
              }
            }
            for next_instr in rebased {
              rewritten.push(next_instr)
            }
            changed = true
          }
          @lib.VoidBlockType if next_body.length() == 1 &&
            (match next_body[0] {
              @lib.Block(@lib.VoidBlockType, @lib.Expr(protected_body)) =>
                run_hot_pipeline_raw_vacuum_body_is_branchy_local_set_call_prefix_parent_unwrap_candidate(
                  body, protected_body,
                )
              _ => false
            }) &&
            !run_hot_pipeline_raw_vacuum_body_targets_owner(next_body, 0) => {
            let rebased = match
              run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(
                next_body, 0,
              ) {
              Some(rebased) => rebased
              None => {
                rewritten.push(instr)
                idx += 1
                continue
              }
            }
            for next_instr in rebased {
              rewritten.push(next_instr)
            }
            changed = true
          }
          @lib.VoidBlockType if body.length() == 1 &&
            body[0] is @lib.Block(@lib.VoidBlockType, _) &&
            run_hot_pipeline_raw_vacuum_body_is_recursive_call_prefix_if_wrapper_candidate(
              next_body,
            ) &&
            !(run_hot_pipeline_raw_vacuum_body_is_tag20_call_local_set_prefix_if_preserve_candidate(
              next_body,
            ) &&
            run_hot_pipeline_raw_vacuum_body_has_multi_local_prefix_parent_continuation(
              instrs, idx,
            )) &&
            !(run_hot_pipeline_raw_vacuum_body_is_five_arg_allocator_release_prefix_if_preserve_candidate(
              next_body,
            ) &&
            run_hot_pipeline_raw_vacuum_body_has_five_arg_prefix_parent_continuation(
              instrs, idx,
            )) &&
            !(run_hot_pipeline_raw_vacuum_body_is_two_arg_call_local_set_prefix_if_preserve_candidate(
              next_body,
            ) &&
            run_hot_pipeline_raw_vacuum_body_has_multi_local_prefix_parent_continuation(
              instrs, idx,
            )) &&
            !run_hot_pipeline_raw_vacuum_instrs_contain_unreachable(next_body) &&
            !run_hot_pipeline_raw_vacuum_body_targets_owner(next_body, 0) => {
            let rebased = match
              run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(
                next_body, 0,
              ) {
              Some(rebased) => rebased
              None => {
                rewritten.push(instr)
                idx += 1
                continue
              }
            }
            for next_instr in rebased {
              rewritten.push(next_instr)
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_f3561_load_retain_prefix_before_terminal_release_preserve_candidate(
              next_body, instrs, idx,
            ) =>
            rewritten.push(
              @lib.Instruction::block(block_type, @lib.Expr::new(next_body)),
            )
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_f4071_sentinel_prefix_before_allocation_preserve_candidate(
              next_body, instrs, idx,
            ) =>
            rewritten.push(
              @lib.Instruction::block(block_type, @lib.Expr::new(next_body)),
            )
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_f4232_sentinel_prefix_before_selected_local_return_preserve_candidate(
              next_body, instrs, idx,
            ) =>
            rewritten.push(
              @lib.Instruction::block(block_type, @lib.Expr::new(next_body)),
            )
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_f4310_side_effect_prefix_before_accumulator_stores_preserve_candidate(
              next_body, instrs, idx,
            ) =>
            rewritten.push(
              @lib.Instruction::block(block_type, @lib.Expr::new(next_body)),
            )
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_f4073_call_result_tag_dispatch_before_slot_store_preserve_candidate(
              next_body, instrs, idx,
            ) =>
            rewritten.push(
              @lib.Instruction::block(block_type, @lib.Expr::new(next_body)),
            )
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_f4483_indexed_call_result_tag1_prefix_preserve_candidate(
              next_body, instrs, idx,
            ) =>
            rewritten.push(
              @lib.Instruction::block(block_type, @lib.Expr::new(next_body)),
            )
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_f5277_indexed_retain_before_tag_continuation_preserve_candidate(
              next_body, instrs, idx,
            ) =>
            rewritten.push(
              @lib.Instruction::block(block_type, @lib.Expr::new(next_body)),
            )
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_f5369_load_call_tag_refcount_dispatch_before_allocation_continuation_preserve_candidate(
              next_body, instrs, idx,
            ) =>
            rewritten.push(
              @lib.Instruction::block(block_type, @lib.Expr::new(next_body)),
            )
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_f6113_retain_call_tag_dispatch_before_parent_continuation_preserve_candidate(
              next_body, instrs, idx,
            ) =>
            rewritten.push(
              @lib.Instruction::block(block_type, @lib.Expr::new(next_body)),
            )
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_f5083_selected_payload_before_conditional_handoff_preserve_candidate(
              next_body, instrs, idx,
            ) =>
            rewritten.push(
              @lib.Instruction::block(block_type, @lib.Expr::new(next_body)),
            )
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_f5027_selected_payload_before_allocation_return_preserve_candidate(
              next_body, instrs, idx,
            ) =>
            rewritten.push(
              @lib.Instruction::block(block_type, @lib.Expr::new(next_body)),
            )
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_f5154_retain_pair_result_before_slot_store_preserve_candidate(
              next_body, instrs, idx,
            ) ||
            run_hot_pipeline_raw_vacuum_body_is_f5184_single_retain_result_before_drop_continuation_preserve_candidate(
              next_body, instrs, idx,
            ) =>
            rewritten.push(
              @lib.Instruction::block(block_type, @lib.Expr::new(next_body)),
            )
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_side_effect_prefix_if_wrapper_candidate(
              body,
            ) &&
            run_hot_pipeline_raw_vacuum_body_is_side_effect_prefix_if_wrapper_candidate(
              next_body,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_is_f1759_tag2_prefix_before_counter_store_preserve_candidate(
              next_body, instrs, idx,
            ) &&
            !(run_hot_pipeline_raw_vacuum_body_is_tag20_call_local_set_prefix_if_preserve_candidate(
              next_body,
            ) &&
            run_hot_pipeline_raw_vacuum_body_has_multi_local_prefix_parent_continuation(
              instrs, idx,
            )) &&
            !(run_hot_pipeline_raw_vacuum_body_is_multi_local_prefix_if_preserve_candidate(
              next_body,
            ) &&
            run_hot_pipeline_raw_vacuum_body_has_multi_local_prefix_parent_continuation(
              instrs, idx,
            )) &&
            !(run_hot_pipeline_raw_vacuum_body_is_f1383_dual_i64_probe_prefix_if_preserve_candidate(
              next_body,
            ) &&
            run_hot_pipeline_raw_vacuum_body_has_multi_local_prefix_parent_continuation(
              instrs, idx,
            )) &&
            !(run_hot_pipeline_raw_vacuum_body_is_call_indirect_prefix_if_preserve_candidate(
              next_body,
            ) &&
            run_hot_pipeline_raw_vacuum_body_has_multi_local_prefix_parent_continuation(
              instrs, idx,
            )) &&
            !run_hot_pipeline_raw_vacuum_body_is_f1224_loop_release_update_preserve_candidate(
              next_body, instrs, idx,
            ) &&
            !(run_hot_pipeline_raw_vacuum_body_is_f1900_increment_probe_prefix_before_reload_preserve_candidate(
              next_body, instrs, idx,
            ) ||
            run_hot_pipeline_raw_vacuum_body_is_f1900_increment_probe_prefix_before_reload_preserve_candidate(
              body, instrs, idx,
            )) &&
            !(run_hot_pipeline_raw_vacuum_body_is_f2094_increment_probe_prefix_before_block_continuation_preserve_candidate(
              next_body, instrs, idx,
            ) ||
            run_hot_pipeline_raw_vacuum_body_is_f2094_increment_probe_prefix_before_block_continuation_preserve_candidate(
              body, instrs, idx,
            )) &&
            !run_hot_pipeline_raw_vacuum_body_is_f3083_loop_body_release_update_prefix_if_preserve_candidate(
              next_body,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_is_f5369_load_call_tag_refcount_dispatch_before_allocation_continuation_preserve_candidate(
              next_body, instrs, idx,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_is_f6113_retain_call_tag_dispatch_before_parent_continuation_preserve_candidate(
              next_body, instrs, idx,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_targets_owner(next_body, 0) => {
            let rebased = match
              run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(
                next_body, 0,
              ) {
              Some(rebased) => rebased
              None => {
                rewritten.push(instr)
                idx += 1
                continue
              }
            }
            for next_instr in rebased {
              rewritten.push(next_instr)
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f4463_offset20_owner_before_failure_box_return(
              next_body, instrs, idx,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f4463_offset20_owner_before_failure_box_return(
                next_body, instrs, idx,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f4311_nested_tag_dispatch_before_call_continuation(
              next_body, instrs, idx,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f4311_nested_tag_dispatch_before_call_continuation(
                next_body, instrs, idx,
              ) {
              Some(flattened) =>
                for next_instr in flattened {
                  rewritten.push(next_instr)
                }
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f4915_tag1_owner_dispatch_before_tag95_return(
              next_body, instrs, idx,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f4915_tag1_owner_dispatch_before_tag95_return(
                next_body, instrs, idx,
              ) {
              Some(flattened) =>
                for next_instr in flattened {
                  rewritten.push(next_instr)
                }
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f4919_call_if_return_before_tag99_return(
              next_body, instrs, idx, module_ctx,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f4919_call_if_return_before_tag99_return(
                next_body, instrs, idx, module_ctx,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f4859_leading_owner_exit_dispatch_before_case0_return(
              next_body, instrs, idx,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f4859_leading_owner_exit_dispatch_before_case0_return(
                next_body, instrs, idx,
              ) {
              Some(flattened) =>
                for next_instr in flattened {
                  rewritten.push(next_instr)
                }
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f4665_nested_tag_classification_before_renderer_continuation(
              next_body, instrs, idx,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f4665_nested_tag_classification_before_renderer_continuation(
                next_body, instrs, idx,
              ) {
              Some(flattened) =>
                for next_instr in flattened {
                  rewritten.push(next_instr)
                }
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_flatten_f4702_call_result_child_before_store_continuation(
              next_body,
            )
            is Some(_) => {
            match
              run_hot_pipeline_raw_vacuum_try_flatten_f4702_call_result_child_before_store_continuation(
                next_body,
              ) {
              Some(flattened) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(flattened)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_f3317_singleton_retain_allocation_loop_wrapper(
              next_body,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_targets_owner(next_body, 0) => {
            match next_body[0] {
              @lib.Block(@lib.VoidBlockType, @lib.Expr(child_body)) =>
                rewritten.push(
                  @lib.Instruction::block(
                    block_type,
                    @lib.Expr::new(
                      match
                        run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(
                          child_body, 0,
                        ) {
                        Some(rebased) => rebased
                        None => {
                          rewritten.push(instr)
                          idx += 1
                          continue
                        }
                      },
                    ),
                  ),
                )
              _ => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_f4071_load_retain_tag_dispatch_before_selected_local_branch_preserve_candidate(
              next_body, instrs, idx,
            ) ||
            run_hot_pipeline_raw_vacuum_body_is_f4071_sentinel_prefix_before_allocation_preserve_candidate(
              next_body, instrs, idx,
            ) ||
            run_hot_pipeline_raw_vacuum_body_is_f4232_sentinel_prefix_before_selected_local_return_preserve_candidate(
              next_body, instrs, idx,
            ) ||
            run_hot_pipeline_raw_vacuum_body_is_f4310_side_effect_prefix_before_accumulator_stores_preserve_candidate(
              next_body, instrs, idx,
            ) ||
            run_hot_pipeline_raw_vacuum_body_is_f4073_call_result_tag_dispatch_before_slot_store_preserve_candidate(
              next_body, instrs, idx,
            ) ||
            run_hot_pipeline_raw_vacuum_body_is_f4483_indexed_call_result_tag1_prefix_preserve_candidate(
              next_body, instrs, idx,
            ) ||
            run_hot_pipeline_raw_vacuum_body_is_f5277_indexed_retain_before_tag_continuation_preserve_candidate(
              next_body, instrs, idx,
            ) ||
            run_hot_pipeline_raw_vacuum_body_is_f6113_retain_call_tag_dispatch_before_parent_continuation_preserve_candidate(
              next_body, instrs, idx,
            ) ||
            run_hot_pipeline_raw_vacuum_body_is_f5154_retain_pair_result_before_slot_store_preserve_candidate(
              next_body, instrs, idx,
            ) ||
            run_hot_pipeline_raw_vacuum_body_is_f5184_single_retain_result_before_drop_continuation_preserve_candidate(
              next_body, instrs, idx,
            ) =>
            rewritten.push(
              @lib.Instruction::block(block_type, @lib.Expr::new(next_body)),
            )
          @lib.VoidBlockType if next_body.length() == 1 &&
            (match next_body[0] {
              @lib.Block(@lib.VoidBlockType, @lib.Expr(child_body)) =>
                run_hot_pipeline_raw_vacuum_body_is_tag_load_dispatch_if_wrapper_candidate(
                  child_body,
                ) &&
                !run_hot_pipeline_raw_vacuum_body_is_f364_four_field_tag_cascade_body(
                  child_body,
                )
              _ => false
            }) => {
            match next_body[0] {
              @lib.Block(@lib.VoidBlockType, @lib.Expr(child_body)) =>
                rewritten.push(
                  @lib.Instruction::block(
                    block_type,
                    @lib.Expr::new(
                      match
                        run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(
                          child_body, 0,
                        ) {
                        Some(rebased) => rebased
                        None => {
                          rewritten.push(instr)
                          idx += 1
                          continue
                        }
                      },
                    ),
                  ),
                )
              _ => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_tag_load_dispatch_if_wrapper_candidate(
              next_body,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_is_f1759_tag2_prefix_before_counter_store_preserve_candidate(
              next_body, instrs, idx,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_is_f364_four_field_tag_cascade_body(
              next_body,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_targets_owner(next_body, 0) => {
            let rebased = match
              run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(
                next_body, 0,
              ) {
              Some(rebased) => rebased
              None => {
                rewritten.push(instr)
                idx += 1
                continue
              }
            }
            for next_instr in rebased {
              rewritten.push(next_instr)
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_terminal_unreachable_block_wrapper_candidate(
              next_body,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_targets_owner(next_body, 0) => {
            let rebased = match
              run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(
                next_body, 0,
              ) {
              Some(rebased) => rebased
              None => {
                rewritten.push(instr)
                idx += 1
                continue
              }
            }
            for next_instr in rebased {
              rewritten.push(next_instr)
            }
            changed = true
          }
          @lib.VoidBlockType if (
              (
                run_hot_pipeline_raw_vacuum_body_is_call_local_set_tag_cascade_if_wrapper_candidate(
                  body,
                ) &&
                run_hot_pipeline_raw_vacuum_body_is_call_local_set_tag_cascade_if_wrapper_candidate(
                  next_body,
                )
              ) ||
              (
                run_hot_pipeline_raw_vacuum_body_is_indexed_call_local_set_tag_cascade_if_wrapper_candidate(
                  body,
                ) &&
                run_hot_pipeline_raw_vacuum_body_is_indexed_call_local_set_tag_cascade_if_wrapper_candidate(
                  next_body,
                )
              )
            ) &&
            !(run_hot_pipeline_raw_vacuum_body_is_f364_four_field_tag_cascade_body(
              next_body,
            ) &&
            run_hot_pipeline_raw_vacuum_body_has_f996_tag_dispatch_parent_continuation(
              instrs, idx,
            )) &&
            !run_hot_pipeline_raw_vacuum_body_targets_owner(next_body, 0) => {
            let rebased = match
              run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(
                next_body, 0,
              ) {
              Some(rebased) => rebased
              None => {
                rewritten.push(instr)
                idx += 1
                continue
              }
            }
            for next_instr in rebased {
              rewritten.push(next_instr)
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_try_wrap_load_linked_release_prefix(
              next_body,
            )
            is Some(_) &&
            !run_hot_pipeline_raw_vacuum_body_targets_owner(next_body, 0) => {
            match
              run_hot_pipeline_raw_vacuum_try_wrap_load_linked_release_prefix(
                next_body,
              ) {
              Some(wrapped) =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(wrapped)),
                )
              None => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_singleton_load_linked_local_set_call_prefix_block(
              body,
            ) &&
            run_hot_pipeline_raw_vacuum_body_is_singleton_load_linked_local_set_call_prefix_block(
              next_body,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_targets_owner(next_body, 0) => {
            match next_body[0] {
              @lib.Block(@lib.VoidBlockType, @lib.Expr(child_body)) =>
                rewritten.push(
                  @lib.Instruction::block(
                    block_type,
                    @lib.Expr::new(
                      match
                        run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(
                          child_body, 0,
                        ) {
                        Some(rebased) => rebased
                        None => {
                          rewritten.push(instr)
                          idx += 1
                          continue
                        }
                      },
                    ),
                  ),
                )
              _ => ()
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_single_flipped_if_wrapper_candidate(
              next_body,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_targets_owner(next_body, 0) => {
            let rebased = match
              run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(
                next_body, 0,
              ) {
              Some(rebased) => rebased
              None => {
                rewritten.push(instr)
                idx += 1
                continue
              }
            }
            for next_instr in rebased {
              rewritten.push(next_instr)
            }
            changed = true
          }
          @lib.VoidBlockType if (
              run_hot_pipeline_raw_vacuum_body_is_unreachable_if_wrapper_candidate(
                next_body,
              ) ||
              run_hot_pipeline_raw_vacuum_body_is_call_tee_unreachable_if_wrapper_candidate(
                next_body,
              ) ||
              run_hot_pipeline_raw_vacuum_body_is_lowered_call_tee_unreachable_if_wrapper_candidate(
                next_body,
              )
            ) &&
            !run_hot_pipeline_raw_vacuum_body_targets_owner(next_body, 0) => {
            let rebased = match
              run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(
                next_body, 0,
              ) {
              Some(rebased) => rebased
              None => {
                rewritten.push(instr)
                idx += 1
                continue
              }
            }
            for next_instr in rebased {
              rewritten.push(next_instr)
            }
            changed = true
          }
          _ if run_hot_pipeline_raw_vacuum_block_type_is_empty(
              module_ctx, block_type,
            ) &&
            (
              run_hot_pipeline_raw_vacuum_body_is_unreachable_if_wrapper_candidate(
                next_body,
              ) ||
              run_hot_pipeline_raw_vacuum_body_is_call_tee_unreachable_if_wrapper_candidate(
                next_body,
              ) ||
              run_hot_pipeline_raw_vacuum_body_is_lowered_call_tee_unreachable_if_wrapper_candidate(
                next_body,
              )
            ) &&
            !run_hot_pipeline_raw_vacuum_body_targets_owner(next_body, 0) => {
            let rebased = match
              run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(
                next_body, 0,
              ) {
              Some(rebased) => rebased
              None => {
                rewritten.push(instr)
                idx += 1
                continue
              }
            }
            for next_instr in rebased {
              rewritten.push(next_instr)
            }
            changed = true
          }
          @lib.VoidBlockType if run_hot_pipeline_raw_vacuum_body_is_if_wrapper_candidate(
              next_body,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_is_f1759_tag2_prefix_before_counter_store_preserve_candidate(
              next_body, instrs, idx,
            ) &&
            !(run_hot_pipeline_raw_vacuum_body_is_call_indirect_prefix_if_preserve_candidate(
              next_body,
            ) &&
            run_hot_pipeline_raw_vacuum_body_has_multi_local_prefix_parent_continuation(
              instrs, idx,
            )) &&
            !(run_hot_pipeline_raw_vacuum_body_is_tag20_call_local_set_prefix_if_preserve_candidate(
              next_body,
            ) &&
            run_hot_pipeline_raw_vacuum_body_has_multi_local_prefix_parent_continuation(
              instrs, idx,
            )) &&
            !(run_hot_pipeline_raw_vacuum_body_is_f1383_dual_i64_probe_prefix_if_preserve_candidate(
              next_body,
            ) &&
            run_hot_pipeline_raw_vacuum_body_has_multi_local_prefix_parent_continuation(
              instrs, idx,
            )) &&
            !(run_hot_pipeline_raw_vacuum_body_is_f1900_increment_probe_prefix_before_reload_preserve_candidate(
              next_body, instrs, idx,
            ) ||
            run_hot_pipeline_raw_vacuum_body_is_f1900_increment_probe_prefix_before_reload_preserve_candidate(
              body, instrs, idx,
            )) &&
            !(run_hot_pipeline_raw_vacuum_body_is_f2094_increment_probe_prefix_before_block_continuation_preserve_candidate(
              next_body, instrs, idx,
            ) ||
            run_hot_pipeline_raw_vacuum_body_is_f2094_increment_probe_prefix_before_block_continuation_preserve_candidate(
              body, instrs, idx,
            )) &&
            !run_hot_pipeline_raw_vacuum_body_is_f3083_loop_body_release_update_prefix_if_preserve_candidate(
              next_body,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_is_f4483_indexed_call_result_tag1_prefix_preserve_candidate(
              next_body, instrs, idx,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_is_f5277_indexed_retain_before_tag_continuation_preserve_candidate(
              next_body, instrs, idx,
            ) &&
            !run_hot_pipeline_raw_vacuum_body_is_f5369_load_call_tag_refcount_dispatch_before_allocation_continuation_preserve_candidate(
              next_body, instrs, idx,
            ) &&
            !run_hot_pipeline_raw_vacuum_instrs_contain_unreachable(next_body) &&
            !run_hot_pipeline_raw_vacuum_body_targets_owner(next_body, 0) => {
            let rebased = match
              run_hot_pipeline_raw_vacuum_rebase_removable_outer_body(
                next_body, 0,
              ) {
              Some(rebased) => rebased
              None => {
                rewritten.push(instr)
                idx += 1
                continue
              }
            }
            for next_instr in rebased {
              rewritten.push(next_instr)
            }
            changed = true
          }
          _ if block_type != @lib.BlockType::void_() &&
            idx + 1 < instrs.length() &&
            instrs[idx + 1] is @lib.Drop &&
            run_hot_pipeline_raw_vacuum_body_has_only_pure_self_branch(
              next_body,
            ) =>
            match
              run_hot_pipeline_raw_vacuum_dropped_control_arities_at(
                instrs, idx, block_type, module_ctx,
              ) {
              Some((param_count, result_count)) => {
                for _ in 0..<param_count {
                  rewritten.push(@lib.Instruction::drop())
                }
                changed = true
                idx += result_count
              }
              None =>
                rewritten.push(
                  @lib.Instruction::block(block_type, @lib.Expr::new(next_body)),
                )
            }
          _ if run_hot_pipeline_raw_vacuum_body_is_static_null_throw_ref_trap(
              next_body,
            ) => {
            for next_instr in next_body {
              rewritten.push(next_instr)
            }
            changed = true
          }
          _ =>
            rewritten.push(
              @lib.Instruction::block(block_type, @lib.Expr::new(next_body)),
            )
        }
      }
      @lib.Loop(block_type, @lib.Expr(body)) => {
        if block_type != @lib.BlockType::void_() &&
          idx + 1 < instrs.length() &&
          instrs[idx + 1] is @lib.Drop &&
          run_hot_pipeline_raw_vacuum_body_is_single_pure_stack_value(body) {
          changed = true
          idx = idx + 2
          continue
        }
        let (next_body, body_changed) = vacuum_worker_review_reference(
          body, module_ctx,
        )
        changed = changed || body_changed
        rewritten.push(
          @lib.Instruction::loop_(block_type, @lib.Expr::new(next_body)),
        )
      }
      @lib.Try(block_type, @lib.Expr(body), catches, delegate) => {
        let (next_body, body_changed) = vacuum_worker_review_reference(
          body, module_ctx,
        )
        changed = changed || body_changed
        if run_hot_pipeline_raw_vacuum_body_can_flatten_no_throw_exception_region(
            next_body,
          ) {
          for next_instr in next_body {
            rewritten.push(next_instr)
          }
          changed = true
        } else {
          let next_catches : Array[@lib.LegacyCatch] = []
          for catch_ in catches {
            match catch_ {
              @lib.LegacyCatch(tag_idx, @lib.Expr(catch_body)) => {
                let (next_catch_body, catch_changed) = vacuum_worker_review_reference(
                  catch_body, module_ctx,
                )
                changed = changed || catch_changed
                next_catches.push(
                  @lib.LegacyCatch::tagged(
                    tag_idx,
                    @lib.Expr::new(next_catch_body),
                  ),
                )
              }
              @lib.LegacyCatchAll(@lib.Expr(catch_body)) => {
                let (next_catch_body, catch_changed) = vacuum_worker_review_reference(
                  catch_body, module_ctx,
                )
                changed = changed || catch_changed
                next_catches.push(
                  @lib.LegacyCatch::all(@lib.Expr::new(next_catch_body)),
                )
              }
            }
          }
          rewritten.push(
            @lib.Instruction::try_(
              block_type,
              @lib.Expr::new(next_body),
              next_catches,
              delegate~,
            ),
          )
        }
      }
      @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
        let (next_body, body_changed) = vacuum_worker_review_reference(
          body, module_ctx,
        )
        changed = changed || body_changed
        if run_hot_pipeline_raw_vacuum_body_is_static_null_throw_ref_trap(
            next_body,
          ) {
          for next_instr in next_body {
            rewritten.push(next_instr)
          }
          changed = true
        } else {
          rewritten.push(
            @lib.Instruction::try_table(
              block_type,
              catches,
              @lib.Expr::new(next_body),
            ),
          )
        }
      }
      @lib.If(block_type, then_body, else_body) => {
        let (clean_then, then_changed) = vacuum_worker_review_reference(
          then_body, module_ctx,
        )
        let (clean_else, else_changed) = match else_body {
          Some(body) => {
            let (cleaned, did_change) = vacuum_worker_review_reference(
              body, module_ctx,
            )
            (Some(cleaned), did_change)
          }
          None => (None, false)
        }
        let mut next_then = clean_then
        let next_else = clean_else
        let mut active_block_type = block_type
        changed = changed || then_changed || else_changed
        let mut normalized_else = match next_else {
          Some(body) if body.length() == 0 => {
            changed = true
            None
          }
          _ => next_else
        }
        let dropped_pure_result_if = match
          (active_block_type, normalized_else) {
          (@lib.ValTypeBlockType(_), Some(else_body)) if idx + 1 <
            instrs.length() &&
            instrs[idx + 1] is @lib.Drop &&
            run_hot_pipeline_raw_vacuum_body_is_single_pure_stack_value(
              next_then,
            ) &&
            run_hot_pipeline_raw_vacuum_body_is_single_pure_stack_value(
              else_body,
            ) => run_hot_pipeline_raw_vacuum_try_pop_pure_stack_expr(rewritten)
          _ => false
        }
        if dropped_pure_result_if {
          changed = true
          idx = idx + 2
          continue
        }
        let has_dropped_result = idx + 1 < instrs.length() &&
          instrs[idx + 1] is @lib.Drop
        let single_result_without_inputs = has_dropped_result &&
          (match active_block_type {
            @lib.ValTypeBlockType(_) => true
            @lib.TypeIdxBlockType(type_idx) =>
              match module_ctx {
                Some(ctx) =>
                  match @ir.hot_module_resolve_type_func_type(ctx, type_idx) {
                    Some(@lib.FuncType(params, results)) =>
                      params.length() == 0 && results.length() == 1
                    None => false
                  }
                None => false
              }
            @lib.VoidBlockType => false
          })
        if single_result_without_inputs {
          match normalized_else {
            Some(else_body) if !run_hot_pipeline_raw_vacuum_body_targets_owner(
                next_then, 0,
              ) &&
              !run_hot_pipeline_raw_vacuum_body_targets_owner(else_body, 0) => {
              let then_concrete = run_hot_pipeline_dce_raw_body_may_fallthrough(
                next_then,
              )
              let else_concrete = run_hot_pipeline_dce_raw_body_may_fallthrough(
                else_body,
              )
              if then_concrete || else_concrete {
                // Append drops only to falling-through values and run ordinary
                // arm cleanup again now that their results are unused.
                if then_concrete {
                  next_then = vacuum_worker_review_reference_dropped_arm(
                    next_then, module_ctx,
                  )
                }
                if else_concrete {
                  let cleaned = vacuum_worker_review_reference_dropped_arm(
                    else_body, module_ctx,
                  )
                  normalized_else = if cleaned.length() == 0 {
                    None
                  } else {
                    Some(cleaned)
                  }
                }
                active_block_type = @lib.BlockType::void_()
                changed = true
                idx = idx + 1
              }
            }
            _ => ()
          }
        }
        let collapsed_constant_result_if = if active_block_type !=
          @lib.BlockType::void_() &&
          rewritten.length() > 0 {
          match rewritten[rewritten.length() - 1] {
            @lib.I32Const(@lib.I32(value)) => {
              let selected = if value != 0 {
                next_then
              } else {
                match normalized_else {
                  Some(body) => body
                  None => []
                }
              }
              if !run_hot_pipeline_raw_vacuum_body_targets_if_or_outer(
                  selected, 0,
                ) {
                ignore(rewritten.pop())
                for selected_instr in selected {
                  rewritten.push(selected_instr)
                }
                true
              } else {
                ignore(rewritten.pop())
                rewritten.push(
                  @lib.Instruction::block(
                    active_block_type,
                    @lib.Expr::new(selected),
                  ),
                )
                true
              }
            }
            _ => false
          }
        } else {
          false
        }
        if collapsed_constant_result_if {
          changed = true
          idx = idx + 1
          continue
        }
        match active_block_type {
          @lib.VoidBlockType if rewritten.length() > 0 =>
            match rewritten[rewritten.length() - 1] {
              @lib.I32Const(@lib.I32(value)) => {
                let selected = if value != 0 {
                  next_then
                } else {
                  match normalized_else {
                    Some(body) => body
                    None => []
                  }
                }
                if !run_hot_pipeline_raw_vacuum_body_targets_if_or_outer(
                    selected, 0,
                  ) {
                  ignore(rewritten.pop())
                  for selected_instr in selected {
                    rewritten.push(selected_instr)
                  }
                  changed = true
                } else {
                  ignore(rewritten.pop())
                  rewritten.push(
                    @lib.Instruction::block(
                      active_block_type,
                      @lib.Expr::new(selected),
                    ),
                  )
                  changed = true
                }
              }
              _ =>
                match normalized_else {
                  Some(else_body) => {
                    if next_then.length() == 0 &&
                      run_hot_pipeline_raw_vacuum_body_is_pure_noop_conditional_ladder(
                        else_body,
                      ) {
                      rewritten.push(
                        @lib.Instruction::if_(
                          active_block_type,
                          next_then,
                          None,
                        ),
                      )
                      changed = true
                      idx = idx + 1
                      continue
                    }
                    if next_then.length() == 0 && else_body.length() > 0 {
                      rewritten.push(@lib.Instruction::i32_eqz())
                      rewritten.push(
                        @lib.Instruction::if_(
                          active_block_type,
                          else_body,
                          None,
                        ),
                      )
                      changed = true
                    } else {
                      rewritten.push(
                        @lib.Instruction::if_(
                          active_block_type, next_then, normalized_else,
                        ),
                      )
                    }
                  }
                  _ if next_then.length() == 0 &&
                    rewritten[rewritten.length() - 1] is @lib.Call(_) => {
                    rewritten.push(@lib.Instruction::drop())
                    changed = true
                  }
                  _ =>
                    rewritten.push(
                      @lib.Instruction::if_(
                        active_block_type, next_then, normalized_else,
                      ),
                    )
                }
            }
          _ =>
            rewritten.push(
              @lib.Instruction::if_(
                active_block_type, next_then, normalized_else,
              ),
            )
        }
      }
      @lib.Unreachable => {
        changed = run_hot_pipeline_raw_vacuum_pop_terminal_unreachable_debris(
            rewritten,
          ) ||
          changed
        rewritten.push(instr)
      }
      _ => {
        if idx + 1 < instrs.length() {
          match (instr, instrs[idx + 1]) {
            (@lib.LocalTee(local_idx), @lib.Drop) => {
              rewritten.push(@lib.Instruction::local_set(local_idx))
              changed = true
              idx = idx + 2
              continue
            }
            _ => ()
          }
        }
        match instr {
          @lib.Drop if rewritten.length() > 0 &&
            (
              run_hot_pipeline_raw_vacuum_try_reduce_dropped_simd_replace_lane_load(
                rewritten,
              ) ||
              run_hot_pipeline_raw_vacuum_try_pop_const_nontrapping_int_divrem(
                rewritten,
              ) ||
              run_hot_pipeline_raw_vacuum_try_pop_pure_stack_expr(rewritten)
            ) => {
            changed = true
            idx = idx + 1
            continue
          }
          @lib.Drop if rewritten.length() > 0 &&
            run_hot_pipeline_raw_vacuum_try_pop_i32_const_compare_keep_lhs(
              rewritten,
            ) => {
            rewritten.push(@lib.Instruction::drop())
            changed = true
            idx = idx + 1
            continue
          }
          _ => ()
        }
        if idx + 1 < instrs.length() &&
          run_hot_pipeline_raw_vacuum_instr_is_pure_drop_leaf(instr) {
          match instrs[idx + 1] {
            @lib.Drop => {
              changed = true
              idx = idx + 2
              continue
            }
            _ => ()
          }
        }
        rewritten.push(instr)
      }
    }
    prev_may_fallthrough = if rewritten.length() == 0 {
      true
    } else {
      match rewritten[rewritten.length() - 1] {
        @lib.Unreachable
        | @lib.Return
        | @lib.ReturnCall(_)
        | @lib.ReturnCallRef(_)
        | @lib.ThrowRef
        | @lib.Br(_)
        | @lib.BrTable(_, _) => false
        _ => true
      }
    }
    idx = idx + 1
  }
  (rewritten, changed)
}

///|
fn vacuum_worker_review_reference_dropped_arm(
  body : Array[@lib.Instruction],
  module_ctx : @ir.HotModuleContext?,
) -> Array[@lib.Instruction] {
  let dropped = body.copy()
  dropped.push(@lib.Instruction::drop())
  let (cleaned, _) = vacuum_worker_review_reference(dropped, module_ctx)
  cleaned
}
