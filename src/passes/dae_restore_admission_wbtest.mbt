///|
test "DAE restoration keeps active scalar bodies without scanning impossible dead suffix candidates" {
  for body in ["local.get 0", "f64.const 7"] {
    let original = pass_test_module_from_wat(
      "(module (func $h (param f64) (result f64) \{body}) (func (export \"run\") (result f64) f64.const 11 call $h))",
    )
    let saved = @binary.encode_module(original).unwrap()
    let scans = [0]
    let result = dae_restore_dead_suffix_self_operand_params(
      original,
      original,
      suffix_scans=Some(scans),
    )
    assert_false(result.changed)
    assert_eq(@binary.encode_module(result.mod_out).unwrap(), saved)
    assert_eq(scans[0], 0)
    @validate.validate_module(result.mod_out).unwrap()
  }
}

///|
test "DAE restoration still restores the escaped self operand parameter on an unreachable body" {
  let original = pass_test_module_from_wat(
    "(module (func $side (export \"side\") (param f64) (result f64) local.get 0) (func $dead (param f64) unreachable local.get 0 call $side call $dead))",
  )
  let current = pass_test_module_from_wat(
    "(module (func $side (export \"side\") (param f64) (result f64) local.get 0) (func $dead unreachable))",
  )
  let saved = @binary.encode_module(current).unwrap()
  let scans = [0]
  let result = dae_restore_dead_suffix_self_operand_params(
    original,
    current,
    candidate_defs=Some([false, true]),
    suffix_scans=Some(scans),
  )
  assert_true(result.changed)
  assert_eq(dae_wb_param_count(result.mod_out, 1), 1)
  assert_eq(scans[0], 1)
  @validate.validate_module(result.mod_out).unwrap()
  assert_eq(@binary.encode_module(current).unwrap(), saved)
  let input_body = current.code_sec.unwrap().0[1]
  assert_eq(result.mod_out.code_sec.unwrap().0[1], input_body)
}

///|
test "DAE restoration admission preserves the reference eligibility and result signatures" {
  for scalar in ["i32", "f64"] {
    for current_param in ["", "(param \{scalar})"] {
      for current_body in ["unreachable", "unreachable nop"] {
        for
          candidates in [
            None,
            Some([false, true]),
            Some([false, false]),
            Some([false]),
          ] {
          let original = pass_test_module_from_wat(
            "(module (func $side (export \"side\") (param \{scalar}) (result \{scalar}) local.get 0) (func $dead (param \{scalar}) (result \{scalar}) unreachable local.get 0 call $side call $dead))",
          )
          let current = pass_test_module_from_wat(
            "(module (func $side (export \"side\") (param \{scalar}) (result \{scalar}) local.get 0) (func $dead \{current_param} (result \{scalar}) \{current_body}))",
          )
          let saved_original = @binary.encode_module(original).unwrap()
          let saved_current = @binary.encode_module(current).unwrap()
          let scans = [0]
          let output = dae_restore_dead_suffix_self_operand_params(
            original,
            current,
            candidate_defs=candidates,
            suffix_scans=Some(scans),
          )
          let reference = dae_restore_admission_reference(
            original,
            current,
            candidate_defs=candidates,
          )
          assert_eq(output.changed, reference.changed)
          assert_eq(output.touched, reference.touched)
          assert_eq(
            @binary.encode_module(output.mod_out).unwrap(),
            @binary.encode_module(reference.mod_out).unwrap(),
          )
          let selected = match candidates {
            None => true
            Some(bitmap) => bitmap.length() > 1 && bitmap[1]
          }
          let eligible = scalar == "f64" &&
            current_param == "" &&
            current_body == "unreachable" &&
            selected
          assert_eq(output.changed, eligible)
          assert_eq(scans[0], if eligible { 1 } else { 0 })
          let indices = dae_collect_func_type_indices(output.mod_out)
          let @lib.FuncType(_, results) = dae_resolve_func_type(
            output.mod_out,
            indices,
            1,
          ).unwrap()
          assert_eq(results, [
            if scalar == "f64" {
              @lib.ValType::f64()
            } else {
              @lib.ValType::i32()
            },
          ])
          @validate.validate_module(output.mod_out).unwrap()
          assert_eq(@binary.encode_module(original).unwrap(), saved_original)
          assert_eq(@binary.encode_module(current).unwrap(), saved_current)
        }
      }
    }
  }
}
