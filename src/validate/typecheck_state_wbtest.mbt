///|
test "typecheck initial local bitmap uses compressed declaration length" {
  let env = empty_env().with_locals(
    @lib.Locals::new([@lib.LocalRun::new(4096U, @lib.ValType::i32())]),
  )
  let expanded_slot_visits = [0]
  let initialized = tc_state_all_locals_initialized(
    env,
    expanded_slot_visits=Some(expanded_slot_visits),
  )

  @debug.assert_eq(initialized.length(), 4096)
  assert_true(initialized.all(fn(value) { value }))
  @debug.assert_eq(expanded_slot_visits[0], 0)
}
