///|
// Binaryen 133 prunes these unused parameters and keeps the three runtime
// function-type identities distinct. Retaining every parameter is a coverage
// gap, rather than a required consequence of preserving type identity.
fn mass_audit_dae2_identity_cascade_fixture() -> @lib.Module {
  pass_test_module_from_wat(
    (
      #| (module
      #|   (type $empty (func))
      #|   (type $one (func (param i32)))
      #|   (type $two (func (param i32 i32)))
      #|   (global $g (export "g") (mut i32) (i32.const 0))
      #|   (table 3 funcref)
      #|   (func $f0 (type $empty))
      #|   (func $f1 (type $one) (param i32))
      #|   (func $f2 (type $two) (param i32 i32)
      #|     local.get 0
      #|     global.set $g)
      #|   (elem (i32.const 0) func $f0 $f1 $f2)
      #|   (func (export "run")
      #|     i32.const 9 call $f1
      #|     i32.const 7 i32.const 9 call $f2
      #|     i32.const 9 call $f1
      #|     i32.const 7 i32.const 9 call $f2
      #|     i32.const 9 call $f1
      #|     i32.const 7 i32.const 9 call $f2
      #|     i32.const 9 call $f1
      #|     i32.const 7 i32.const 9 call $f2))
    ),
  )
}

///|
test "mass audit dae2 prunes referenced signature collisions without merging runtime identities" {
  let input = mass_audit_dae2_identity_cascade_fixture()
  let saved = @binary.encode_module(input).unwrap()
  for pass_name in ["dae2", "dae2-optimizing"] {
    let output = run_hot_pipeline(
      input,
      HotPipelineOptions::new(closed_world=true),
      [pass_name],
    ).unwrap()
    @validate.validate_module(output).unwrap()
    let context = @ir.hot_module_context_from_module(output)
    assert_eq(
      @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(0U)),
      Some(@lib.FuncType::new([], [])),
    )
    assert_eq(
      @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(1U)),
      Some(@lib.FuncType::new([], [])),
    )
    assert_eq(
      @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(2U)),
      Some(@lib.FuncType::new([@lib.ValType::i32()], [])),
    )
    let identities = dae2_identity_partition(output.type_sec.unwrap())
    let @lib.FuncSec(indices) = output.func_sec.unwrap()
    guard indices[0] is @lib.TypeIdx(first) else {
      abort("expected module type index")
    }
    guard indices[1] is @lib.TypeIdx(second) else {
      abort("expected module type index")
    }
    assert_true(identities[first.to_int()] != identities[second.to_int()])
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[2]
    assert_eq(body, [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
    ])
    let encoded = @binary.encode_module(output).unwrap()
    @validate.validate_module(@binary.decode_module(encoded).unwrap()).unwrap()
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "mass audit dae2 retains imported call target signature through a local" {
  for
    (import_module, import_name, local_type) in [
      ("binaryen-intrinsics", "call.without.effects", "funcref"),
      ("binaryen-intrinsics", "call.without.effects", "(ref null $sig)"),
      ("env", "invoke", "(ref null $sig)"),
    ] {
    let input = pass_test_module_from_wat(
      "(module (type $sig (func (param i32) (result i32))) (import \"\{import_module}\" \"\{import_name}\" (func $invoke (param i32 funcref) (result i32))) (func $target (type $sig) (param i32) (result i32) i32.const 11) (elem declare func $target) (func (export \"run\") (param i32) (result i64) (local \{local_type}) ref.func $target local.set 1 i32.const 3 local.get 1 call $invoke i64.extend_i32_u))",
    )
    let saved = @binary.encode_module(input).unwrap()
    for pass_name in ["dae2", "dae2-optimizing"] {
      let output = run_hot_pipeline(
        input,
        HotPipelineOptions::new(closed_world=true),
        [pass_name],
      ).unwrap()
      @validate.validate_module(output).unwrap()
      let context = @ir.hot_module_context_from_module(output)
      // Calling the retained target must still produce 11. With its result
      // removed, the imported callback converts undefined to i32 zero.
      assert_eq(
        @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(1U)),
        Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
      )
      let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
      assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(11))])
      let encoded = @binary.encode_module(output).unwrap()
      @validate.validate_module(@binary.decode_module(encoded).unwrap()).unwrap()
    }
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
