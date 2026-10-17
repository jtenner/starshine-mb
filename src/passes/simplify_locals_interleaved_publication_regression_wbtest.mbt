///|
// Preserve an observable write between consumers of a shared pair value.
// Additional source reads contribute to the result, so dead cleanup cannot
// remove them before alias selection.
fn sl_interleaved_read_fixture(
  additional_parameter_reads : Int32,
) -> @lib.Module {
  let mut extra_reads = ""
  for _ in 0..<additional_parameter_reads {
    extra_reads += "local.get 0 i32.add "
  }
  pass_test_module_from_wat(
    "(module (type $pair (func (result i32 i32))) " +
    "(func (export \"run\") (param i32) (result i32) (local i32 i32 i32) " +
    "local.get 0 local.set 1 " +
    "block (type $pair) " +
    "local.get 1 i32.const 1 i32.add " +
    "local.get 1 i32.const 2 i32.add end " +
    "local.set 2 " +
    "i32.const 99 local.set 1 " +
    "local.set 3 local.get 1 local.get 2 i32.add local.get 3 i32.add " +
    extra_reads +
    "))",
  )
}

///|
fn sl_interleaved_read_check(additional_parameter_reads : Int32) -> Unit raise {
  let input = sl_interleaved_read_fixture(additional_parameter_reads)
  ignore(@validate.validate_module(input).unwrap())
  // The owner overwrite is observable in the returned sum. The two saved
  // producer lanes must retain x+1 and x+2, while local1 must now contain99.
  for argument in [0, 10, -7] {
    assert_eq(
      sl_multivalue_source_execute(input.code_sec.unwrap().0[0], argument),
      (Some((additional_parameter_reads + 2) * argument + 102), []),
      msg="original interleaved owner overwrite, additional reads=\{additional_parameter_reads}",
    )
  }
  for
    passes in [
      ["simplify-locals"],
      ["simplify-locals", "simplify-locals"],
      ["simplify-locals-nostructure"],
      ["simplify-locals-nostructure", "simplify-locals-nostructure"],
    ] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), passes).unwrap()
    ignore(@validate.validate_module(output).unwrap())
    for argument in [0, 10, -7] {
      assert_eq(
        sl_multivalue_source_execute(output.code_sec.unwrap().0[0], argument),
        (Some((additional_parameter_reads + 2) * argument + 102), []),
        msg="interleaved owner overwrite, additional reads=\{additional_parameter_reads}, passes=\{passes}, input=\{argument}",
      )
    }
  }
}

///|
test "simplify-locals interleaved read keeps owner overwrite between lane publications" {
  sl_interleaved_read_check(0)
}

///|
test "simplify-locals interleaved read keeps owner overwrite with two observable extra source reads" {
  sl_interleaved_read_check(2)
}

///|
test "simplify-locals interleaved read keeps owner overwrite with four observable extra source reads" {
  sl_interleaved_read_check(4)
}
