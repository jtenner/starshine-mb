///|
test "tuple dispatcher Call-parent copy keeps every lane write outside the cleared carrier" {
  // This exact case fails on native a379: return0/events[11,12,0]. The
  // original returns23/events[11,12,11]; local6 in the bad output has no write.
  let input = @passes.pass_test_module_from_wat(
    "(module (type $pair (func (result i32 i32))) " +
    "(import \"env\" \"mark\" (func $mark (param i32) (result i32))) " +
    "(func (export \"run\") (param i32) (result i32) (local i32 i32 i32 i32) " +
    "block (type $pair) local.get 0 i32.const 1 i32.add call $mark " +
    "local.get 0 i32.const 2 i32.add call $mark end local.set 2 local.set 1 " +
    "block (result i32) local.get 2 local.set 4 local.get 1 end local.tee 3 call $mark " +
    "local.get 4 i32.add))",
  )
  ignore(@validate.validate_module(input).unwrap())
  let expected : (Int32?, Array[Int32]) = (Some(23), [11, 12, 11])
  assert_eq(
    tuple_prefix_cmd_execute(input.code_sec.unwrap().0[0], arguments=[10]),
    expected,
  )
  for
    passes in [
      ["tuple-optimization"],
      ["tuple-optimization", "tuple-optimization"],
      [
        "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals", "vacuum",
        "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals", "vacuum",
      ],
    ] {
    let output = tuple_opaque_growth_run(input, passes)
    let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
    ignore(@validate.validate_module(decoded).unwrap())
    assert_eq(
      tuple_prefix_cmd_execute(decoded.code_sec.unwrap().0[0], arguments=[10]),
      expected,
    )
  }
}

///|
test "tuple dispatcher Call-parent copy preserves earlier operands and later lane observations" {
  let cases : Array[(String, (Int32?, Array[Array[Int32]]))] = [
    (
      "i32.const 77 call $mark block (result i32) local.get 2 local.set 4 local.get 1 end " +
      "local.tee 3 call $observe local.get 4 i32.add",
      (Some(111), [[0, 11], [0, 100], [0, 77], [1, 77, 11]]),
    ),
    (
      "i32.const 1 i32.const 0 i32.div_s block (result i32) local.get 2 local.set 4 local.get 1 end " +
      "local.tee 3 call $observe local.get 4 i32.add",
      (None, [[0, 11], [0, 100]]),
    ),
    (
      "block (result i32) local.get 2 local.set 4 local.get 1 end local.tee 3 " +
      "local.get 4 call $mark call $observe local.get 3 i32.add",
      (Some(111), [[0, 11], [0, 100], [0, 100], [1, 11, 100]]),
    ),
  ]
  for (tail, expected) in cases {
    let input = @passes.pass_test_module_from_wat(
      "(module (type $pair (func (result i32 i32))) " +
      "(import \"env\" \"mark\" (func $mark (param i32) (result i32))) " +
      "(import \"env\" \"observe\" (func $observe (param i32 i32) (result i32))) " +
      "(func (export \"run\") (param i32) (result i32) (local i32 i32 i32 i32) " +
      "block (type $pair) i32.const 11 call $mark i32.const 100 call $mark end local.set 2 local.set 1 " +
      tail +
      "))",
    )
    ignore(@validate.validate_module(input).unwrap())
    assert_eq(
      tuple_call_boundary_cmd_execute(input.code_sec.unwrap().0[0]),
      expected,
    )
    for
      passes in [
        ["tuple-optimization"],
        ["tuple-optimization", "tuple-optimization"],
        [
          "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals",
          "vacuum", "tuple-optimization", "simplify-locals-nostructure", "coalesce-locals",
          "vacuum",
        ],
      ] {
      let output = tuple_opaque_growth_run(input, passes)
      let decoded = @binary.decode_module(
        @binary.encode_module(output).unwrap(),
      ).unwrap()
      ignore(@validate.validate_module(decoded).unwrap())
      assert_eq(
        tuple_call_boundary_cmd_execute(decoded.code_sec.unwrap().0[0]),
        expected,
      )
    }
  }
}
