///|
test "command DAE2 rejects invalid function subtypes with unequal arities" {
  // Function variance permits different parameter types, never different arity.
  for signature in ["", "(param i32 i64)", "(param i32) (result i32)"] {
    let input = @wast.wast_to_binary_module(
      "(module (rec (type $P (sub (func (param i32)))) (type $Q (sub $P (func \{signature})))))",
    ).unwrap()
    assert_true(@validate.validate_module(input) is Err(_))
    for pass in ["dae2", "dae2-optimizing"] {
      assert_true(
        optimize_module_with_pass_flags(
          input,
          [pass],
          OptimizeOptions::new(closed_world=true),
        )
        is Err(_),
      )
    }
  }
}

///|
test "command DAE2 keeps indirect family targets with unequal parameter demand compatible" {
  let input = @wast.wast_to_binary_module(
    "(module (type $sig (func (param i32 i64))) (global $side (mut i32) (i32.const 0)) (table 2 funcref) (func $idle (type $sig)) (func $live (type $sig) local.get 0 global.set $side) (elem (i32.const 0) $idle $live) (func (export \"run\") (param i32) (result i32) i32.const 7 i64.const 9 local.get 0 call_indirect (type $sig) global.get $side))",
  ).unwrap()
  for pass in ["dae2", "dae2-optimizing"] {
    let output = optimize_module_with_pass_flags(
      input,
      [pass],
      OptimizeOptions::new(closed_world=true),
    ).unwrap()
    @validate.validate_module(output).unwrap()
    let env = @validate.Env::new().with_module(output)
    let expected = Some(@lib.FuncType::new([@lib.ValType::i32()], []))
    for index in [0U, 1U] {
      assert_eq(env.get_functype_by_funcidx(@lib.FuncIdx::new(index)), expected)
    }
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[2]
    guard body[body.length() - 2] is @lib.CallIndirect(type_idx, _) else {
      fail("expected indirect dispatch")
    }
    assert_eq(env.resolve_functype(type_idx), expected)
  }
}

///|
test "command DAE2 keeps contravariant recursive family signatures at indirect dispatch" {
  let input = @wast.wast_to_binary_module(
    "(module (rec (type $P (sub (func (param eqref i32)))) (type $Q (sub $P (func (param anyref i32))))) (global $side (mut i32) (i32.const 0)) (table 2 funcref) (func $live (type $P) local.get 0 ref.is_null global.set $side) (func $idle (type $Q)) (elem (i32.const 0) $live $idle) (func (export \"run\") (param i32) (result i32) ref.null eq i32.const 7 local.get 0 call_indirect (type $P) global.get $side))",
  ).unwrap()
  @validate.validate_module(input).unwrap()
  let input_env = @validate.Env::new().with_module(input)
  let @lib.FuncType(parent_params, _) = input_env
    .resolve_functype(@lib.TypeIdx::new(0U))
    .unwrap()
  let @lib.FuncType(child_params, _) = input_env
    .resolve_functype(@lib.TypeIdx::new(1U))
    .unwrap()
  for pass in ["dae2", "dae2-optimizing"] {
    let output = optimize_module_with_pass_flags(
      input,
      [pass],
      OptimizeOptions::new(closed_world=true),
    ).unwrap()
    @validate.validate_module(output).unwrap()
    let env = @validate.Env::new().with_module(output)
    assert_eq(
      env.get_functype_by_funcidx(@lib.FuncIdx::new(0U)),
      Some(@lib.FuncType::new([parent_params[0]], [])),
    )
    assert_eq(
      env.get_functype_by_funcidx(@lib.FuncIdx::new(1U)),
      Some(@lib.FuncType::new([child_params[0]], [])),
    )
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[2]
    guard body[body.length() - 2] is @lib.CallIndirect(type_idx, _) else {
      fail("expected recursive-family indirect dispatch")
    }
    assert_eq(
      env.resolve_functype(type_idx),
      Some(@lib.FuncType::new([parent_params[0]], [])),
    )
  }
}

///|
test "command DAE2 modes preserve recursive identity split and collapse" {
  for
    (other_param, body, equivalent) in [
      ("i64", "", false),
      ("i32", "local.get 0 global.set $side", true),
    ] {
    let input = @wast.wast_to_binary_module(
      "(module (rec (type $A (func (param i32))) (type $AX (struct (field (ref null $A))))) (rec (type $B (func (param \{other_param}))) (type $BX (struct (field (ref null $B))))) (global $side (export \"side\") (mut i32) (i32.const 0)) (table 1 funcref) (func $a (type $A) \{body}) (elem (i32.const 0) func $a) (func (export \"run\") \{other_param}.const 7 i32.const 0 call_indirect (type $B)))",
    ).unwrap()
    @validate.validate_module(input).unwrap()
    for pass in ["dae2", "dae2-optimizing"] {
      let output = optimize_module_with_pass_flags(
        input,
        [pass],
        OptimizeOptions::new(closed_world=true),
      ).unwrap()
      @validate.validate_module(output).unwrap()
      let env = @validate.Env::new().with_module(output)
      assert_eq(
        env.resolve_functype(@lib.TypeIdx::new(0U)) ==
        env.resolve_functype(@lib.TypeIdx::new(2U)),
        equivalent,
      )
    }
  }
}
