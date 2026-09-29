///|
// Frozen original all-verifier: the control entry point performs core checks
// too, so this deliberately contains the redundant complete core walk.
fn core_once_reference_all(func : HotFunc) -> Result[Unit, HotVerifyError] {
  match hot_verify_core(func) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  hot_verify_control(func)
}

///|
fn core_once_assert_result(
  func : HotFunc,
  expected : Result[Unit, HotVerifyError],
) -> Unit raise {
  let revision = hot_revision_current(func)
  let calls = [0]
  assert_eq(
    hot_verify_all_impl(func, core_verification_calls=Some(calls)),
    expected,
  )
  assert_eq(hot_verify_all(func, cache=Some(())), expected)
  assert_eq(hot_verify_all(func, cache=Some(7)), expected)
  assert_eq(hot_verify_all(func), core_once_reference_all(func))
  assert_eq(calls[0], 1)
  assert_eq(hot_revision_current(func), revision)
}

///|
test "all verification completes exactly one core walk on valid control and catch fixtures" {
  for roots in [0, 16] {
    for with_catch in [false, true] {
      core_once_assert_result(
        catch_layout_perf_fixture(roots, with_catch),
        Ok(()),
      )
    }
  }
  let func = cfg_segment_storage_fixture(4)
  core_once_assert_result(func, Ok(()))
  cfg_verify(cfg_build(func, expand_operand_control=true))
}

///|
test "all verification preserves core error precedence and full control rejection" {
  let both_invalid = HotFunc::new()
  hot_body_result_type_set(
    both_invalid,
    hot_type_intern_value(both_invalid, @lib.ValType::i32()),
  )
  let branch = hot_build_br(both_invalid, HOT_IMPLICIT_FUNCTION_LABEL)
  hot_root_append(both_invalid, branch)
  let missing = hot_node_count(both_invalid) + 7
  both_invalid.roots.push(missing)
  core_once_assert_result(
    both_invalid,
    Err(HotVerifyError::InvalidRoot(1, missing)),
  )
  ignore(both_invalid.roots.pop())
  core_once_assert_result(
    both_invalid,
    Err(
      HotVerifyError::InvalidBranchArity(
        branch,
        HOT_IMPLICIT_FUNCTION_LABEL,
        0,
        1,
      ),
    ),
  )

  let orphan = HotFunc::new()
  let payload = hot_build_catch_payload(
    orphan,
    @lib.TagIdx::new(0U),
    @lib.ValType::i32(),
  )
  hot_root_append(orphan, hot_build_drop(orphan, payload))
  let expected = core_once_reference_all(orphan)
  assert_true(expected is Err(HotVerifyError::InvalidCatchPayload(_, _)))
  core_once_assert_result(orphan, expected)
}
