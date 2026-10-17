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

///|
test "unread tee retirement keeps lower-level Vacuum admission unchanged" {
  for (optimize_level, shrink_level) in [(0, 0), (4, 0), (3, 1)] {
    let input = pass_test_module_from_wat(
      "(module (import \"env\" \"produce\" (func (result i32))) (func (export \"run\") (result i32) (local i32) call 0 local.tee 0))",
    )
    let original = @binary.encode_module(input).unwrap()
    let output = run_hot_pipeline(
      input,
      HotPipelineOptions::new(
        optimize_level~,
        shrink_level~,
        verify_policy=HotPipelineVerifyPolicy::after_each_pass(),
      ),
      ["vacuum", "reorder-locals"],
    ).unwrap()
    @debug.assert_eq(@binary.encode_module(output).unwrap(), original)
  }
}

///|
test "unread tee proof intentionally falls back above its compressed local budget" {
  let ty = @lib.ValType::i32()
  @debug.assert_eq(
    run_hot_pipeline_vacuum_unread_tee_local_count(
      1,
      @lib.Locals::single(65535U, ty),
    ),
    Some(65536),
  )
  @debug.assert_eq(
    run_hot_pipeline_vacuum_unread_tee_local_count(
      1,
      @lib.Locals::single(65536U, ty),
    ),
    None,
  )
  @debug.assert_eq(
    run_hot_pipeline_vacuum_unread_tee_local_count(65537, @lib.Locals::empty()),
    None,
  )
  // Inspect only the compressed count; this never expands or optimizes it.
  @debug.assert_eq(
    run_hot_pipeline_vacuum_unread_tee_local_count(
      0,
      @lib.Locals::single(0xffffffffU, ty),
    ),
    None,
  )
  @debug.assert_eq(
    run_hot_pipeline_vacuum_unread_tee_local_count(-1, @lib.Locals::empty()),
    None,
  )
  @debug.assert_eq(
    run_hot_pipeline_vacuum_unread_tee_local_count(
      0,
      @lib.Locals::new([
        @lib.LocalRun::new(32768U, ty),
        @lib.LocalRun::new(32769U, @lib.ValType::i64()),
      ]),
    ),
    None,
  )
}

///|
test "O4s unread tee cleanup retains an exported parameter signature" {
  let (input, output) = vacuum_unread_tee_test_run(
    "(module (func (export \"run\") (param i32) (result i32) i32.const 7 local.tee 0))",
  )
  @debug.assert_eq(output.func_sec, input.func_sec)
  @debug.assert_eq(output.type_sec, input.type_sec)
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(locals.length(), 0)
  @debug.assert_eq(body, [@lib.Instruction::i32_const(7)])
}

///|
test "O4s unread tee cleanup traverses TryTable without changing its catch target" {
  let (_, output) = vacuum_unread_tee_test_run(
    "(module (import \"env\" \"produce\" (func (result i32))) (global $seen (mut i32) (i32.const 0)) (func (export \"run\") (local i32) block try_table (catch_all 0) call 0 local.tee 0 global.set $seen end end))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(locals.length(), 0)
  let expected = pass_test_module_from_wat(
    "(module (import \"env\" \"produce\" (func (result i32))) (global $seen (mut i32) (i32.const 0)) (func (export \"run\") block try_table (catch_all 0) call 0 global.set $seen end end))",
  )
  let @lib.Func(_, @lib.Expr(expected_body)) = expected.code_sec.unwrap().0[0]
  @debug.assert_eq(body, expected_body)
}
