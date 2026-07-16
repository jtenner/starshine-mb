///|
test "hot verify accepts valid lifted hot funcs and concrete overlays" {
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
  let cfg = cfg_build(func)
  let dom = dom_build(cfg)
  let use_def = use_def_build(func, cfg=Some(cfg))
  let liveness = liveness_build(cfg, use_def)
  let ssa = ssa_build_local(func, cfg, dom, liveness, use_def)
  match hot_verify_cfg(func, cfg) {
    Ok(_) => ()
    Err(err) => fail(err.to_string())
  }
  match hot_verify_dominators(cfg, dom) {
    Ok(_) => ()
    Err(err) => fail(err.to_string())
  }
  match hot_verify_ssa(func, cfg, ssa) {
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
      @debug.assert_eq(node_id, branch)
      @debug.assert_eq(label_id, 99)
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
      @debug.assert_eq(node_id, bad_branch)
      @debug.assert_eq(label_id, hot_control_node_label(invalid_arity, block))
      @debug.assert_eq(actual, 0)
      @debug.assert_eq(expected, 1)
    }
    other => fail("expected invalid branch arity, got \{other}")
  }
}

///|
test "hot verify requires typed catch payloads as an ordered catch-region prefix" {
  let valid = HotFunc::new()
  let payload = hot_build_catch_payload(
    valid,
    @lib.TagIdx::new(3U),
    @lib.ValType::i32(),
  )
  let consume = hot_build_drop(valid, payload)
  let try_id = hot_build_try(
    valid,
    @lib.BlockType::void_(),
    [hot_build_nop(valid)],
    catch_body=Some([payload, consume]),
  )
  hot_root_append(valid, try_id)
  @debug.assert_eq(hot_catch_payload_tag(valid, payload), @lib.TagIdx::new(3U))
  @debug.assert_eq(hot_type_results(valid, hot_node_type(valid, payload)), [
    @lib.ValType::i32(),
  ])
  match hot_verify_control(valid) {
    Ok(_) => ()
    Err(err) => fail(err.to_string())
  }

  let outside = HotFunc::new()
  let outside_payload = hot_build_catch_payload(
    outside,
    @lib.TagIdx::new(0U),
    @lib.ValType::i32(),
  )
  hot_root_append(outside, outside_payload)
  match hot_verify_control(outside) {
    Err(HotVerifyError::InvalidCatchPayload(node_id, _)) =>
      @debug.assert_eq(node_id, outside_payload)
    other => fail("expected outside catch payload rejection, got \{other}")
  }

  let late = HotFunc::new()
  let late_payload = hot_build_catch_payload(
    late,
    @lib.TagIdx::new(1U),
    @lib.ValType::i32(),
  )
  let late_try = hot_build_try(
    late,
    @lib.BlockType::void_(),
    [hot_build_nop(late)],
    catch_body=Some([
      hot_build_nop(late),
      late_payload,
      hot_build_drop(late, late_payload),
    ]),
  )
  hot_root_append(late, late_try)
  match hot_verify_control(late) {
    Err(HotVerifyError::InvalidCatchPayload(node_id, _)) =>
      @debug.assert_eq(node_id, late_payload)
    other => fail("expected late catch payload rejection, got \{other}")
  }
}
