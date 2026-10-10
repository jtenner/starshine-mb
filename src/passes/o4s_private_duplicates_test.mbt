///|
test "O4s merges private duplicates across a host boundary" {
  let input = @passes.pass_test_module_from_wat(
    (
      #|(module
      #|  (import "env" "observe" (func $observe (param i32)))
      #|  (func $a (result i32) i32.const 42)
      #|  (func $b (result i32) i32.const 42)
      #|  (func (export "run") (result i32)
      #|    call $a call $observe call $b))
    ),
  )
  let before = @binary.encode_module(input).unwrap()
  let output = @passes.run_hot_pipeline(
    input,
    @passes.HotPipelineOptions::new(optimize_level=4, shrink_level=1),
    ["optimize"],
  ).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(output.code_sec.unwrap().0.length(), 2)
  assert_eq(output.import_sec, input.import_sec)
  assert_eq(
    output.export_sec.unwrap().0[0],
    @lib.Export::new(
      @lib.Name::from_string("run"),
      @lib.ExternIdx::func(@lib.FuncIdx::new(2U)),
    ),
  )
  let @lib.Func(_, run_body) = output.code_sec.unwrap().0[1]
  assert_eq(
    run_body,
    @lib.Expr::new([
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    ]),
  )
  assert_true(@binary.encode_module(output).unwrap().length() < before.length())
  assert_eq(@binary.encode_module(input).unwrap(), before)
}

///|
test "O4s private merging preserves exported and materialized identities" {
  let input = @passes.pass_test_module_from_wat(
    (
      #|(module
      #|  (func $private_a (result i32) i32.const 42)
      #|  (func $private_b (result i32) i32.const 42)
      #|  (func $a (export "a") (result i32) i32.const 42)
      #|  (func $b (export "b") (result i32) i32.const 42)
      #|  (func $ref_a (result i32) i32.const 42)
      #|  (func $ref_b (result i32) i32.const 42)
      #|  (table (export "refs") 2 funcref)
      #|  (elem (i32.const 0) func $ref_a $ref_b)
      #|  (global (export "first_ref") funcref (ref.func $ref_a))
      #|  (global (export "second_ref") funcref (ref.func $ref_b))
      #|  (func (export "run") (result i32)
      #|    call $private_a call $private_b i32.add))
    ),
  )
  for preset in ["optimize", "shrink"] {
    let output = @passes.run_hot_pipeline(
      input,
      @passes.HotPipelineOptions::new(optimize_level=4, shrink_level=1),
      [preset],
    ).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(output.code_sec.unwrap().0.length(), 6)
    let exports = output.export_sec.unwrap().0
    for item in [(0, 1U), (1, 2U), (5, 5U)] {
      let (entry_idx, func_idx) = item
      assert_eq(
        exports[entry_idx],
        @lib.Export::new(
          @lib.Name::from_string(
            if entry_idx == 0 {
              "a"
            } else if entry_idx == 1 {
              "b"
            } else {
              "run"
            },
          ),
          @lib.ExternIdx::func(@lib.FuncIdx::new(func_idx)),
        ),
      )
    }
    let @lib.Elem(_, elem_kind) = output.elem_sec.unwrap().0[0]
    assert_eq(
      elem_kind,
      @lib.ElemKind::funcs([@lib.FuncIdx::new(3U), @lib.FuncIdx::new(4U)]),
    )
    let globals = output.global_sec.unwrap().0
    let @lib.Global(_, first_init) = globals[0]
    let @lib.Global(_, second_init) = globals[1]
    assert_eq(
      first_init,
      @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(3U))]),
    )
    assert_eq(
      second_init,
      @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(4U))]),
    )
  }
}
