///|
test "hot verify accepts valid lifted hot funcs and placeholder overlays" {
  let func = hot_lift_body(
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::void_(),
        @lib.Expr::new([
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
    HotLocals::new(),
  )

  match hot_verify_core(func) {
    Ok(_) => ()
    Err(err) => fail(err.to_string())
  }
  match hot_verify_control(func) {
    Ok(_) => ()
    Err(err) => fail(err.to_string())
  }
  match hot_verify_all(func, cache=Some(())) {
    Ok(_) => ()
    Err(err) => fail(err.to_string())
  }
  match hot_verify_cfg(func, "cfg-placeholder") {
    Ok(_) => ()
    Err(err) => fail(err.to_string())
  }
  match hot_verify_dominators("cfg-placeholder", "dom-placeholder") {
    Ok(_) => ()
    Err(err) => fail(err.to_string())
  }
  match hot_verify_ssa(func, "cfg-placeholder", "ssa-placeholder") {
    Ok(_) => ()
    Err(err) => fail(err.to_string())
  }
  hot_verify_all_or_abort(func)
}

///|
test "hot verify core reports invalid body result types" {
  let invalid_body_result = HotFunc::new(body_result_type=9)
  match hot_verify_core(invalid_body_result) {
    Err(HotVerifyError::InvalidBodyResultType(9)) => ()
    other => fail("expected invalid body result type, got \{other}")
  }
}

///|
test "hot verify control reports invalid branch targets and payload arity" {
  let invalid_target = HotFunc::new()
  let branch = hot_build_br(invalid_target, 99)
  hot_root_append(invalid_target, branch)
  match hot_verify_control(invalid_target) {
    Err(HotVerifyError::InvalidBranchTarget(node_id, label_id)) => {
      assert_eq(node_id, branch)
      assert_eq(label_id, 99)
    }
    other => fail("expected invalid branch target, got \{other}")
  }

  let invalid_arity = HotFunc::new()
  let block = hot_build_block(
    invalid_arity,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let bad_branch = hot_build_br(
    invalid_arity,
    hot_control_node_label(invalid_arity, block),
  )
  hot_region_replace_body(
    invalid_arity,
    hot_region_body_ref(invalid_arity, block),
    [bad_branch],
  )
  hot_root_append(invalid_arity, block)
  match hot_verify_control(invalid_arity) {
    Err(HotVerifyError::InvalidBranchArity(node_id, label_id, actual, expected)) => {
      assert_eq(node_id, bad_branch)
      assert_eq(label_id, hot_control_node_label(invalid_arity, block))
      assert_eq(actual, 0)
      assert_eq(expected, 1)
    }
    other => fail("expected invalid branch arity, got \{other}")
  }
}
