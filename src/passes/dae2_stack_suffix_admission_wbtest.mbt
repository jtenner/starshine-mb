///|
test "dae2 suffix admission shares control and call collection without changing their metadata" {
  for
    (body, expected, control, calls) in [
      ("loop end", 1, [], []),
      ("i32.const 0 if loop end else block end end", 1, [], []),
      ("block return end", 3, [], []),
      ("i32.const 7 block (type $input) drop end", 3, [17], []),
      ("return", 2, [], []),
      ("call $sink", 0, [], [0]),
      ("loop call $sink end", 1, [], [0]),
      ("i32.const 0 call_indirect (type $void)", 2, [], [23]),
    ] {
    let input = pass_test_module_from_wat(
      "(module (type $input (func (param i32))) (type $void (func)) (table 1 funcref) (func $sink) (func (export \"run\") \{body}))",
    )
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let @lib.Func(_, @lib.Expr(instructions)) = input.code_sec.unwrap().0[1]
    let info = Dae2Function::new(Dae2Graph::new(), [], [])
    let state = Dae2StackSuffixState::new(2)
    let found = dae2_collect_control_type_infos(
      instructions,
      [17, 23],
      info.control_type_infos,
      call_infos=Some(info.call_infos),
      suffix_state=Some(state),
      function_index=1,
    )
    assert_eq(found, !calls.is_empty())
    assert_eq(info.control_type_infos, control)
    assert_eq(info.call_infos, calls)
    assert_eq(state.admissions, [0, expected])
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
