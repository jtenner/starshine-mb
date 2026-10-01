///|
fn release_cleanup_fixture(kind : String) -> String {
  let (extra_types, producer, consumer, local_type) = match kind {
    "i32" =>
      (
        "", "local.get 0 i32.load offset=4", "local.get 1 local.get 3 i32.ge_s",
        "i32",
      )
    "i64" =>
      (
        "", "local.get 0 i64.load offset=4", "local.get 1 i64.extend_i32_s local.get 3 i64.ge_s",
        "i64",
      )
    "ref" =>
      (
        "(import \"env\" \"produce\" (func $produce (result externref))) (import \"env\" \"use\" (func $use (param i32 externref) (result i32)))",
        "call $produce", "local.get 0 local.get 3 call $use", "externref",
      )
    "gc" =>
      (
        "(type $box (struct (field i32))) (func $produce (result (ref $box)) i32.const 9 struct.new $box) (func $use (param i32 (ref $box)) (result i32) local.get 1 struct.get $box 0)",
        "call $produce", "local.get 0 local.get 3 call $use", "(ref $box)",
      )
    _ => abort("unknown release cleanup fixture")
  }
  "(module (import \"env\" \"combine\" (func $combine (param i32 i32))) (import \"env\" \"release\" (func $release (param i32))) \{extra_types} (memory (export \"memory\") 1) (func (export \"run\") (param i32 i32 i32) (result i32) (local \{local_type} i32) \{producer} local.set 3 \{consumer} local.set 4 local.get 0 local.get 1 call $combine local.get 2 if local.get 0 call $release local.get 1 call $release end local.get 4))"
}

///|
fn release_cleanup_count_sets(body : Array[@lib.Instruction]) -> Int {
  let mut count = 0
  for instr in body {
    match instr {
      @lib.LocalSet(_) => count += 1
      @lib.Block(_, @lib.Expr(nested))
      | @lib.Loop(_, @lib.Expr(nested))
      | @lib.TryTable(_, _, @lib.Expr(nested)) =>
        count += release_cleanup_count_sets(nested)
      @lib.If(_, yes, no) => {
        count += release_cleanup_count_sets(yes)
        if no is Some(nested) {
          count += release_cleanup_count_sets(nested)
        }
      }
      _ => ()
    }
  }
  count
}

///|
test "simplify-locals cleans independent effectful scalar and reference captures beside structured releases" {
  for kind in ["i32", "i64", "ref", "gc"] {
    let wat = release_cleanup_fixture(kind)
    let input = pass_test_module_from_wat(wat)
    @validate.validate_module(input).unwrap()
    let @lib.Func(_, @lib.Expr(original)) = input.code_sec.unwrap().0
      .last()
      .unwrap()
    assert_true(
      run_hot_pipeline_raw_has_call_argument_structured_release(original),
    )
    assert_eq(release_cleanup_count_sets(original), 2)
    let output = pass_test_run_pipeline(wat, ["simplify-locals"]).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0
      .last()
      .unwrap()
    assert_eq(release_cleanup_count_sets(body), 1, msg=kind)
  }
}

///|
fn release_cleanup_assert_local_barrier(
  producer : String,
  prefix : String,
) -> Unit raise {
  let wat = "(module (import \"env\" \"combine\" (func $combine (param i32 i32))) (import \"env\" \"release\" (func $release (param i32))) (memory 1) (func (export \"run\") (param i32 i32 i32) (result i32) (local i32 i32) \{producer} local.set 3 \{prefix} local.get 3 i32.ge_s local.set 4 local.get 0 local.get 1 call $combine local.get 2 if local.get 0 call $release local.get 1 call $release end local.get 4))"
  let input = pass_test_module_from_wat(wat)
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let all_locals = @lib.Locals::from_types(Array::make(3, @lib.ValType::i32()))
  all_locals.append(locals)
  let env = @validate.Env::new().with_module(input).with_locals(all_locals)
  let result = run_hot_pipeline_raw_simplify_locals_rewrite_effectful_suffix_local_gets_flat(
    body, env,
  )
  // This relocation is intentionally unsupported: the crossed local access
  // changes the producer or prefix value, despite both output shapes validating.
  assert_eq(result.1, 0)
  assert_eq(result.0, body)
}

///|
test "effectful suffix cleanup keeps nested producer reads before clobbering prefixes" {
  release_cleanup_assert_local_barrier(
    "block (result i32) local.get 1 end", "i32.const 5 local.set 1 local.get 0",
  )
}

///|
test "effectful suffix cleanup keeps prefix reads after legacy producer writes" {
  release_cleanup_assert_local_barrier(
    "(try (result i32) (do i32.const 11 local.set 1 local.get 0 i32.load) (catch_all i32.const 13))",
    "local.get 1",
  )
}

///|
test "effectful prefix extensions require closed valid i32 leaf inputs" {
  let env = @validate.Env::new().with_locals(
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i64()]),
  )
  for
    extension in [
      @lib.Instruction::i64_extend_i32s(),
      @lib.Instruction::i64_extend_i32u(),
    ] {
    assert_true(
      sl_effectful_prefix_can_append_i64_extension(
        [@lib.Instruction::local_get(@lib.LocalIdx::new(0U))],
        extension,
        env,
      ),
    )
    assert_true(
      sl_effectful_prefix_can_append_i64_extension(
        [@lib.Instruction::i32_const(@lib.I32(-1))],
        extension,
        env,
      ),
    )
    // Ambient-stack inputs and invalid typed leaves are intentionally outside
    // this closed-prefix admission; they cannot authorize a producer move.
    for
      prefix in [
        [],
        [@lib.Instruction::local_get(@lib.LocalIdx::new(1U))],
        [@lib.Instruction::local_get(@lib.LocalIdx::new(2U))],
      ] {
      assert_false(
        sl_effectful_prefix_can_append_i64_extension(prefix, extension, env),
      )
    }
  }
}
