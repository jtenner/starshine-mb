///|
#skip("dedicated synthetic declared-local work-bound preservation control")
test "DAE2 sparse stamp allocation preserves old admission with many unwritten declared locals" {
  let locals = Array::make(3100, "i32").join(" ")
  let code = StringBuilder()
  code.write_string("block $out ")
  for local in 4..<12 {
    code.write_string("local.get 1 local.set \{local} ")
  }
  for _ in 0..<64 {
    code.write_string(
      "local.get 1 local.set 4 local.get 2 local.set 5 local.get 0 br_if $out ",
    )
  }
  code.write_string("end local.get 4 local.get 5 i32.add local.get 6 i32.add")
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i32 i32 i64) (result i32) (local \{locals}) \{code.to_string()}) (func (export \"run\") (param i32 i32 i32) (result i32) local.get 0 local.get 1 local.get 2 i64.const 9 call $h))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let context = @ir.hot_module_context_from_module(input)
  let graph = Dae2Graph::new()
  let info = Dae2Function::new(
    graph,
    [
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i64(),
    ],
    [@lib.ValType::i32()],
  )
  let old_plan = dae2_sparse_reference_forward_dependency_plan(
    graph,
    [info],
    0,
    [],
    input.code_sec.unwrap().0[0],
    None,
    Some(context),
  )
  assert_true(
    old_plan is Some(_),
    msg="old eight-times planner admission must be proved first",
  )
  dae2_sparse_incoming_compare(input)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
