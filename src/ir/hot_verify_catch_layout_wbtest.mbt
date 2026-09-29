///|
test "catch-free control verification avoids an unused layout workspace" {
  let func = HotFunc::new()
  for _ in 0..<16 {
    hot_root_append(func, hot_build_nop(func))
  }
  let calls = [0]
  let revision = hot_revision_current(func)
  assert_eq(
    hot_verify_control_impl(func, catch_layout_calls=Some(calls)),
    Ok(()),
  )
  assert_eq(hot_verify_control(func), catch_layout_reference_control(func))
  assert_eq(calls[0], 0)
  assert_eq(hot_revision_current(func), revision)

  let invalid = HotFunc::new()
  hot_body_result_type_set(
    invalid,
    hot_type_intern_value(invalid, @lib.ValType::i32()),
  )
  let branch = hot_build_br(invalid, HOT_IMPLICIT_FUNCTION_LABEL)
  hot_root_append(invalid, branch)
  assert_eq(
    hot_verify_control_impl(invalid, catch_layout_calls=Some(calls)),
    catch_layout_reference_control(invalid),
  )
  match hot_verify_control(invalid) {
    Err(HotVerifyError::InvalidBranchArity(node, _, actual, expected)) => {
      assert_eq(node, branch)
      assert_eq(actual, 0)
      assert_eq(expected, 1)
    }
    other =>
      fail("expected invalid function-exit arity rejection, got \{other}")
  }
  assert_eq(calls[0], 0)
}

///|
test "catch layout admission preserves payload checks and error precedence" {
  let valid = HotFunc::new()
  let payload = hot_build_catch_payload(
    valid,
    @lib.TagIdx::new(0U),
    @lib.ValType::i32(),
  )
  let try_node = hot_build_try(
    valid,
    @lib.BlockType::void_(),
    [hot_build_nop(valid)],
    catch_body=Some([payload, hot_build_drop(valid, payload)]),
  )
  hot_root_append(valid, try_node)
  let calls = [0]
  assert_eq(
    hot_verify_control_impl(valid, catch_layout_calls=Some(calls)),
    Ok(()),
  )
  assert_eq(hot_verify_control(valid), catch_layout_reference_control(valid))
  assert_eq(calls[0], 1)

  let orphan = HotFunc::new()
  let orphan_payload = hot_build_catch_payload(
    orphan,
    @lib.TagIdx::new(0U),
    @lib.ValType::i32(),
  )
  hot_root_append(orphan, hot_build_drop(orphan, orphan_payload))
  calls[0] = 0
  assert_eq(
    hot_verify_control_impl(orphan, catch_layout_calls=Some(calls)),
    catch_layout_reference_control(orphan),
  )
  match hot_verify_control(orphan) {
    Err(HotVerifyError::InvalidCatchPayload(node, _)) =>
      assert_eq(node, orphan_payload)
    other => fail("expected orphan catch payload rejection, got \{other}")
  }
  assert_eq(calls[0], 1)
}

///|
// Frozen original full control verifier, including unconditional layout scan.
fn catch_layout_reference_control(
  func : HotFunc,
) -> Result[Unit, HotVerifyError] {
  match hot_verify_core(func) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }

  for node_id = 0; node_id < func.nodes.length(); node_id = node_id + 1 {
    if !hot_node_is_live(func, node_id) {
      continue
    }
    let node = hot_node_get(func, node_id)
    match node.op {
      HotOp::Block | HotOp::Loop | HotOp::If | HotOp::Try | HotOp::TryTable =>
        match hot_verify_control_label_kind(func, node_id, node) {
          Ok(_) => ()
          Err(err) => return Err(err)
        }
      _ => ()
    }

    match node.op {
      HotOp::Block | HotOp::Loop =>
        for slot = 0; slot < node.child_count; slot = slot + 1 {
          let child_id = hot_child_get(func, node_id, slot)
          if child_id == HOT_NONE_NODE {
            return Err(
              HotVerifyError::InvalidControlChild(node_id, slot, child_id),
            )
          }
        }
      HotOp::If => {
        let entry_count = match hot_type_get(func, node.ty) {
          BlockResultResolved(_, params, _) => params.length()
          _ => 0
        }
        if node.child_count != 3 + entry_count {
          return Err(
            HotVerifyError::InvalidControlChildCount(
              node_id,
              node.child_count,
              3 + entry_count,
            ),
          )
        }
        let condition_id = hot_child_get(func, node_id, 0)
        if condition_id == HOT_NONE_NODE ||
          !hot_node_is_live(func, condition_id) {
          return Err(
            HotVerifyError::InvalidControlChild(node_id, 0, condition_id),
          )
        }
        for slot in 3..<node.child_count {
          let entry = hot_child_get(func, node_id, slot)
          if entry == HOT_NONE_NODE || !hot_node_is_live(func, entry) {
            return Err(
              HotVerifyError::InvalidControlChild(node_id, slot, entry),
            )
          }
        }
        let then_region = hot_child_get(func, node_id, 1)
        if !hot_verify_region_holder(func, then_region) {
          return Err(
            HotVerifyError::InvalidControlChild(node_id, 1, then_region),
          )
        }
        let else_region = hot_child_get(func, node_id, 2)
        if else_region != HOT_NONE_NODE &&
          !hot_verify_region_holder(func, else_region) {
          return Err(
            HotVerifyError::InvalidControlChild(node_id, 2, else_region),
          )
        }
      }
      HotOp::Try => {
        if node.child_count != 2 {
          return Err(
            HotVerifyError::InvalidControlChildCount(
              node_id,
              node.child_count,
              2,
            ),
          )
        }
        for slot = 0; slot < 2; slot = slot + 1 {
          let child_id = hot_child_get(func, node_id, slot)
          if slot == 1 && child_id == HOT_NONE_NODE {
            continue
          }
          if !hot_verify_region_holder(func, child_id) {
            return Err(
              HotVerifyError::InvalidControlChild(node_id, slot, child_id),
            )
          }
        }
      }
      HotOp::Continuation => {
        for target in hot_continuation_targets(func, node_id) {
          if target != HOT_IMPLICIT_FUNCTION_LABEL &&
            !hot_verify_label_id_is_valid(func, target) {
            return Err(HotVerifyError::InvalidBranchTarget(node_id, target))
          }
        }
        let expected = hot_continuation_handlers(
            hot_node_exact_instr(func, node_id).unwrap(),
          )
          .filter(fn(handler) { handler is @lib.ResumeOnLabel(_, _) })
          .length()
        if expected != hot_continuation_targets(func, node_id).length() {
          return Err(
            HotVerifyError::InvalidCatchPayload(
              node_id, "continuation handler target count",
            ),
          )
        }
      }
      HotOp::TryTable => {
        if node.child_count != 2 {
          return Err(
            HotVerifyError::InvalidControlChildCount(
              node_id,
              node.child_count,
              2,
            ),
          )
        }
        for slot = 0; slot < 2; slot = slot + 1 {
          let child_id = hot_child_get(func, node_id, slot)
          if !hot_verify_region_holder(func, child_id) {
            return Err(
              HotVerifyError::InvalidControlChild(node_id, slot, child_id),
            )
          }
        }
        let catch_info = hot_catch_info_get(func, node.imm1)
        for catch_arm in catch_info.catches {
          let target = match catch_arm {
            HotCatchArm::CatchArm(_, label_id)
            | HotCatchArm::CatchRefArm(_, label_id)
            | HotCatchArm::CatchAllArm(label_id)
            | HotCatchArm::CatchAllRefArm(label_id) => label_id
          }
          if target != HOT_IMPLICIT_FUNCTION_LABEL &&
            !hot_verify_label_id_is_valid(func, target) {
            return Err(HotVerifyError::InvalidBranchTarget(node_id, target))
          }
        }
      }
      HotOp::Br
      | HotOp::BrIf
      | HotOp::BrTable
      | HotOp::BrOnNull
      | HotOp::BrOnNonNull
      | HotOp::BrOnCast
      | HotOp::BrOnCastFail
      | HotOp::Delegate => {
        let actual_arity = match
          hot_verify_branch_payload_arity(func, node_id) {
          Some(arity) => arity
          None =>
            return Err(
              HotVerifyError::InvalidControlChildCount(
                node_id,
                node.child_count,
                1,
              ),
            )
        }
        match node.op {
          HotOp::Br =>
            match
              hot_verify_branch_target(func, node_id, node.imm0, actual_arity) {
              Ok(_) => ()
              Err(err) => return Err(err)
            }
          HotOp::Delegate =>
            match
              hot_verify_branch_target(func, node_id, node.imm0, actual_arity) {
              Ok(_) => ()
              Err(err) => return Err(err)
            }
          HotOp::BrIf
          | HotOp::BrOnNull
          | HotOp::BrOnNonNull
          | HotOp::BrOnCast
          | HotOp::BrOnCastFail => {
            let guard_id = hot_child_get(func, node_id, node.child_count - 1)
            if guard_id == HOT_NONE_NODE || !hot_node_is_live(func, guard_id) {
              return Err(
                HotVerifyError::InvalidControlChild(
                  node_id,
                  node.child_count - 1,
                  guard_id,
                ),
              )
            }
            match
              hot_verify_branch_target(func, node_id, node.imm0, actual_arity) {
              Ok(_) => ()
              Err(err) => return Err(err)
            }
          }
          HotOp::BrTable => {
            let selector_id = hot_child_get(func, node_id, node.child_count - 1)
            if selector_id == HOT_NONE_NODE ||
              !hot_node_is_live(func, selector_id) {
              return Err(
                HotVerifyError::InvalidControlChild(
                  node_id,
                  node.child_count - 1,
                  selector_id,
                ),
              )
            }
            let targets = hot_branch_table_targets_for_node(func, node_id)
            let all_targets = targets.copy()
            all_targets.push(hot_branch_table_default_target(func, node.imm0))
            match
              hot_verify_branch_targets(
                func, node_id, all_targets, actual_arity,
              ) {
              Ok(_) => ()
              Err(err) => return Err(err)
            }
          }
          _ => ()
        }
      }
      _ => ()
    }
  }

  match hot_verify_catch_payload_layout(func) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  Ok(())
}
