///|
fn dae_core_trace_handoff_fixture() -> @lib.Module {
  pass_test_module_from_wat(
    (
      #|(module
      #|  (func (export "run") (result i32) i32.const 7 call $target)
      #|  (func $sibling (result i32) i32.const 5)
      #|  (func $target (param i32) (result i32)
      #|    local.get 0 i32.const 1 i32.add))
    ),
  )
}

///|
test "DAE core retains the post trace gate for an intentionally invalid aliased sibling" {
  let reference_input = dae_core_trace_handoff_fixture()
  let reference_trace : Array[String] = []
  let reference = dae_run_core(reference_input, fn(message) {
    reference_trace.push(message)
  })
  let reference_indices = dae_collect_func_type_indices(reference.mod_out)
  assert_eq(
    dae_resolve_func_type(reference.mod_out, reference_indices, 2),
    Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
  )
  @validate.validate_module(reference.mod_out).unwrap()
  let input = dae_core_trace_handoff_fixture()
  let @lib.Func(_, @lib.Expr(sibling_body)) = input.code_sec.unwrap().0[1]
  let mutated = [false]
  let observed_trace : Array[String] = []
  let actual = dae_run_core(input, fn(message) {
    observed_trace.push(message)
    if !mutated[0] && message.contains("core-worklist-batch start=0") {
      // The callback is intentionally hostile. It edits an aliased input body
      // after the inner producer gate but before the outer transaction gate.
      sibling_body[0] = @lib.Instruction::i64_const(@lib.I64(5L))
      mutated[0] = true
    }
  })
  assert_true(mutated[0])
  assert_true(
    reference_trace.any(fn(message) {
      message.contains("core-worklist-batch start=0")
    }),
  )
  assert_true(
    observed_trace.any(fn(message) {
      message.contains("core-worklist-batch start=0")
    }),
  )
  let indices = dae_collect_func_type_indices(actual.mod_out)
  assert_eq(
    dae_resolve_func_type(actual.mod_out, indices, 2),
    Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
  )
  assert_eq(actual.mod_out.func_sec, input.func_sec)
  assert_eq(actual.mod_out.code_sec, input.code_sec)
  assert_eq(actual.diagnostics.candidates_applied, 0)
  assert_true(@validate.validate_module(actual.mod_out) is Err(_))
}
