///|
test "P00 legacy rethrow targets a catch label among all control labels" {
  let env = empty_env().with_label([]).with_legacy_catch_depth(1).with_label([])
  let st = tcneg_make_state(env, [])
  tcneg_assert_err_contains(typecheck_rethrow(st, LabelIdx::new(0U)), "rethrow")
  assert_true(typecheck_rethrow(st, LabelIdx::new(1U)) is Ok(_))
  tcneg_assert_err_contains(
    typecheck_rethrow(st, LabelIdx::new(0xFFFFFFFFU)),
    "rethrow",
  )
}
