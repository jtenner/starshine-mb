///|
fn simplify_locals_command_case437_typed_loop_module() -> @lib.Module {
  match
    @binary.decode_module(
      Bytes::from_array([
        0, 97, 115, 109, 1, 0, 0, 0, 1, 10, 2, 96, 1, 127, 0, 96, 1, 127, 1, 127,
        3, 2, 1, 1, 7, 7, 1, 3, 114, 117, 110, 0, 0, 10, 35, 1, 33, 1, 1, 127, 32,
        0, 65, 16, 113, 33, 0, 65, 0, 3, 0, 33, 1, 32, 1, 65, 1, 106, 32, 0, 32,
        1, 75, 13, 0, 26, 11, 32, 1, 11,
      ]),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      abort("expected command case437 typed-loop decode success, got \{err}")
  }
}

///|
test "command simplify-locals stackifies exact adjacent typed-loop local traffic" {
  let input = simplify_locals_command_case437_typed_loop_module()
  assert_true(@validate.validate_module(input) is Ok(_))
  let output = cmd_deep_audit_run_module(input, "simplify-locals")
  assert_true(@validate.validate_module(output) is Ok(_))
  let encoded = match @binary.encode_module(output) {
    Ok(bytes) => bytes
    Err(err) =>
      fail("expected command case437 output encode success, got \{err}")
  }
  @debug.assert_eq(encoded.length(), 68)
  let pretty = output.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.tee (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
}
