///|
fn vacuum_unread_tee_test_run(
  text : String,
) -> (@lib.Module, @lib.Module) raise {
  let input = pass_test_module_from_wat(text)
  let original = @binary.encode_module(input).unwrap()
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(
      optimize_level=4,
      shrink_level=1,
      verify_policy=HotPipelineVerifyPolicy::after_each_pass(),
    ),
    ["optimize"],
  ).unwrap()
  @validate.validate_module(output).unwrap()
  @debug.assert_eq(@binary.encode_module(input).unwrap(), original)
  (input, output)
}

///|
test "O4s vacuum retires globally unread scalar and reference tees after effectful producers" {
  for
    (result_type, local_type) in [
      ("i32", "i32"),
      ("externref", "externref"),
      ("i64 i32", "i32"),
    ] {
    let (_, output) = vacuum_unread_tee_test_run(
      "(module (import \"env\" \"produce\" (func (result \{result_type}))) (func (export \"run\") (result \{result_type}) (local \{local_type}) call 0 local.tee 0))",
    )
    let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    @debug.assert_eq(locals.length(), 0)
    @debug.assert_eq(body, [@lib.Instruction::call(@lib.FuncIdx::new(0U))])
  }
}

///|
test "O4s vacuum retires an unread nullable GC tee while retaining its producer" {
  for ty in ["(ref null $s)", "(ref $s)"] {
    let (_, output) = vacuum_unread_tee_test_run(
      "(module (type $s (struct (field i32))) (import \"env\" \"produce\" (func (result \{ty}))) (func (export \"run\") (result \{ty}) (local \{ty}) call 0 local.tee 0))",
    )
    let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    @debug.assert_eq(locals.length(), 0)
    @debug.assert_eq(body, [@lib.Instruction::call(@lib.FuncIdx::new(0U))])
  }
}

///|
test "O4s vacuum retires unread tees in structured loop bodies without moving calls" {
  let (_, output) = vacuum_unread_tee_test_run(
    "(module (import \"env\" \"produce\" (func (result i32))) (global $seen (export \"seen\") (mut i32) (i32.const 0)) (func (export \"run\") (local i32) block loop call 0 local.tee 0 global.set $seen br 1 end end))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(locals.length(), 0)
  let gets = [0]
  let tees = [0]
  run_hot_pipeline_raw_collect_local_ref_counts(body, gets, [], tees)
  @debug.assert_eq(tees, [0])
  let expected = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func (result i32))) (global $seen (export \"seen\") (mut i32) (i32.const 0)) (func (export \"run\") block loop call 0 global.set $seen br 1 end end))",
  )
  let @lib.Func(_, @lib.Expr(expected_body)) = expected.code_sec.unwrap().0[0]
  @debug.assert_eq(body, expected_body)
}

///|
test "O4s unread tee proof retains reads in the other arm and legacy handlers" {
  for
    tail in [
      "global.get $seen if nop else local.get 0 global.set $seen end", "(try (do call 0 drop) (catch_all local.get 0 global.set $seen))",
    ] {
    let (_, output) = vacuum_unread_tee_test_run(
      "(module (import \"env\" \"produce\" (func (result i32))) (global $seen (export \"seen\") (mut i32) (i32.const 0)) (func (local i32) call 0 local.tee 0 drop \{tail}))",
    )
    let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    @debug.assert_eq(locals.length(), 1)
    let gets = [0]
    let sets = [0]
    let tees = [0]
    run_hot_pipeline_raw_collect_local_ref_counts(body, gets, sets, tees)
    assert_true(gets[0] > 0)
    // Vacuum may independently canonicalize a tee followed by drop to a set.
    assert_true(sets[0] + tees[0] > 0)
  }
}

///|
test "O4s unread tee cleanup preserves live parameters and stack value order" {
  let (_, output) = vacuum_unread_tee_test_run(
    "(module (import \"env\" \"produce\" (func (result i32))) (func (export \"run\") (param i32) (result i32) (local i32) call 0 local.tee 1 local.get 0 i32.add))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(locals.length(), 0)
  @debug.assert_eq(body, [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::i32_add(),
  ])
}
