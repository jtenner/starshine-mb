///|
test "DAE direct GC batch shares unchanged public boundary facts and preserves caller state" {
  for width in [2, 4, 8] {
    let rows = Array::makei(width, fn(index) {
      "(func (export \"f\{index}\") (result i32) i32.const \{index + 7})"
    }).join(" ")
    let input = pass_test_module_from_wat("(module " + rows + ")")
    ignore(@validate.validate_module(input).unwrap())
    let saved = @binary.encode_module(input).unwrap()
    let touched = Array::makei(width, fn(index) { index == 0 })
    let builds = [0]
    let output = dae_apply_direct_gc_batch_transaction(
      dae_collect_original_boundary_snapshot(input),
      input,
      touched,
      true,
      graph_builds=Some(builds),
    )
    assert_false(output.applied)
    assert_true(output.changed)
    assert_eq(output.primary_def, -1)
    assert_eq(output.touched, touched)
    assert_eq(output.effects.structurally_touched, Array::make(width, false))
    assert_true(output.effects.invalidation_domains.is_empty())
    assert_eq(@binary.encode_module(output.mod_out).unwrap(), saved)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    ignore(@validate.validate_module(output.mod_out).unwrap())
    assert_eq(builds[0], 1, msg="one immutable module needs one boundary graph")
  }
}

///|
test "DAE direct GC batch avoids graphs when no definition is active" {
  for text in ["(module)", "(module (func (export \"f\") nop))"] {
    let input = pass_test_module_from_wat(text)
    let saved = @binary.encode_module(input).unwrap()
    let builds = [0]
    let output = dae_apply_direct_gc_batch_transaction(
      dae_collect_original_boundary_snapshot(input),
      input,
      [],
      false,
      active_defs=Some([]),
      graph_builds=Some(builds),
    )
    assert_false(output.changed)
    assert_false(output.applied)
    assert_eq(output.touched, [])
    assert_eq(output.primary_def, -1)
    assert_eq(@binary.encode_module(output.mod_out).unwrap(), saved)
    ignore(@validate.validate_module(output.mod_out).unwrap())
    assert_eq(builds[0], 0)
  }
}

///|
test "DAE direct GC batch refreshes boundary facts after each committed refinement" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $base (sub (struct)))
      #|  (type $leaf (sub $base (struct)))
      #|  (import "host" "mark" (func $mark (param i32) (result i32)))
      #|  (func $identity (param (ref null $base)) (result (ref null $base))
      #|    local.get 0)
      #|  (func (export "unchanged") (result i32) i32.const 9)
      #|  (func $check (param (ref null $base)) (result i32)
      #|    local.get 0 ref.is_null)
      #|  (func (export "run") (result i32)
      #|    i32.const 5 call $mark drop
      #|    struct.new_default $leaf call $identity drop
      #|    struct.new_default $leaf call $check))
    ),
  )
  ignore(@validate.validate_module(input).unwrap())
  let saved = @binary.encode_module(input).unwrap()
  let builds = [0]
  let output = dae_apply_direct_gc_batch_transaction(
    dae_collect_original_boundary_snapshot(input),
    input,
    [],
    false,
    graph_builds=Some(builds),
  )
  assert_true(output.changed)
  assert_true(output.applied)
  assert_eq(output.primary_def, 0)
  let expected = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=false,
    ),
  )
  let indices = dae_collect_func_type_indices(output.mod_out)
  assert_eq(
    dae_resolve_func_type(output.mod_out, indices, 1),
    Some(@lib.FuncType::new([expected], [expected])),
  )
  assert_eq(
    dae_resolve_func_type(output.mod_out, indices, 3),
    Some(@lib.FuncType::new([expected], [@lib.ValType::i32()])),
  )
  let @lib.Func(_, @lib.Expr(original_run)) = input.code_sec.unwrap().0[3]
  let @lib.Func(_, @lib.Expr(actual_run)) = output.mod_out.code_sec.unwrap().0[3]
  assert_eq(actual_run, original_run)
  assert_true(output.effects.parameter_type_refined[0])
  assert_true(output.effects.parameter_type_refined[2])
  assert_true(output.effects.result_changed[0])
  ignore(@validate.validate_module(output.mod_out).unwrap())
  let encoded = @binary.encode_module(output.mod_out).unwrap()
  ignore(
    @validate.validate_module(@binary.decode_module(encoded).unwrap()).unwrap(),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_eq(builds[0], 3)
}

///|
test "DAE direct GC batch refreshes after an original ownership rejection before a later commit" {
  let common =
    #| (type $base (sub (struct)))
    #| (type $leaf (sub $base (struct)))
    #| (func $escaped (param (ref null $base)) (result i32) local.get 0 ref.is_null)
    #| (func $private (param (ref null $base)) (result i32) local.get 0 ref.is_null)
    #| (func (export "run") (result i32)
    #|   struct.new_default $leaf call $escaped drop
    #|   struct.new_default $leaf call $private)
  let original = pass_test_module_from_wat(
    "(module (table 1 funcref) (elem (i32.const 0) func $escaped) " +
    common +
    ")",
  )
  let current = pass_test_module_from_wat("(module " + common + ")")
  ignore(@validate.validate_module(original).unwrap())
  ignore(@validate.validate_module(current).unwrap())
  let saved = @binary.encode_module(current).unwrap()
  let builds = [0]
  let output = dae_apply_direct_gc_batch_transaction(
    dae_collect_original_boundary_snapshot(original),
    current,
    [],
    false,
    graph_builds=Some(builds),
  )
  assert_true(output.applied)
  assert_eq(output.primary_def, 1)
  let indices = dae_collect_func_type_indices(output.mod_out)
  let base = @lib.ValType::ref_type(
    @lib.RefType::new(
      true,
      @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      exact=false,
    ),
  )
  let leaf = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(1U)),
      exact=false,
    ),
  )
  assert_eq(
    dae_resolve_func_type(output.mod_out, indices, 0),
    Some(@lib.FuncType::new([base], [@lib.ValType::i32()])),
  )
  assert_eq(
    dae_resolve_func_type(output.mod_out, indices, 1),
    Some(@lib.FuncType::new([leaf], [@lib.ValType::i32()])),
  )
  assert_false(output.effects.parameter_type_refined[0])
  assert_true(output.effects.parameter_type_refined[1])
  ignore(@validate.validate_module(output.mod_out).unwrap())
  assert_eq(@binary.encode_module(current).unwrap(), saved)
  assert_eq(builds[0], 3)
}
