///|
test "mass repair dae2 preserves one and two private element identities after pruning" {
  for
    wat in [
      "(module (type $A (func (param i32))) (table 1 funcref) (func $a (type $A)) (elem (i32.const 0) func $a) (func (export \"run\") i32.const 9 call $a))",
      "(module (type $A (func (param i32))) (type $B (func (param i64))) (table 2 funcref) (func $a (type $A)) (func $b (type $B)) (elem (i32.const 0) func $a $b) (func (export \"run\") i32.const 9 call $a i64.const 7 call $b))",
    ] {
    let input = pass_test_module_from_wat(wat)
    let saved = @binary.encode_module(input).unwrap()
    for pass_name in ["dae2", "dae2-optimizing"] {
      let output = run_hot_pipeline(
        input,
        HotPipelineOptions::new(closed_world=true),
        [pass_name],
      ).unwrap()
      @validate.validate_module(output).unwrap()
      let context = @ir.hot_module_context_from_module(output)
      let @lib.FuncSec(indices) = output.func_sec.unwrap()
      let identities = dae2_identity_partition(output.type_sec.unwrap())
      guard indices[0] is @lib.TypeIdx(first) else {
        abort("expected module type index")
      }
      for index = 0; index < indices.length(); index = index + 1 {
        assert_eq(
          @ir.hot_module_resolve_func_type(
            context,
            @lib.FuncIdx::new(index.to_uint()),
          ),
          Some(@lib.FuncType::new([], [])),
        )
        if index > 0 {
          guard indices[index] is @lib.TypeIdx(other) else {
            abort("expected module type index")
          }
          assert_true(identities[first.to_int()] != identities[other.to_int()])
        }
      }
      @validate.validate_module(
        @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap(),
      ).unwrap()
    }
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "mass repair dae2 keeps a concrete imported reference parameter contract" {
  let input = pass_test_module_from_wat(
    "(module (type $sig (func (param i32) (result i32))) (import \"env\" \"invoke\" (func $invoke (param (ref null $sig)) (result i32))) (func $target (type $sig) i32.const 11) (elem declare func $target) (func (export \"run\") (result i32) (local (ref null $sig)) ref.func $target local.set 0 local.get 0 call $invoke))",
  )
  for pass_name in ["dae2", "dae2-optimizing"] {
    let output = run_hot_pipeline(
      input,
      HotPipelineOptions::new(closed_world=true),
      [pass_name],
    ).unwrap()
    let context = @ir.hot_module_context_from_module(output)
    assert_eq(
      @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(1U)),
      Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
    )
    @validate.validate_module(
      @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap(),
    ).unwrap()
  }
}
