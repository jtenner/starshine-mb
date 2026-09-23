///|
fn oi_local_group_parity_fixture() -> @lib.Module {
  pass_test_module_from_wat(
    "(module (func (export \"run\") (result i32) (local i32 f64 i32) i32.const 41 local.set 2 local.get 2))",
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_decl_runs_preserving_groups([
          @lib.LocalRun::new(1U, @lib.ValType::i32()),
          @lib.LocalRun::new(1U, @lib.ValType::f64()),
          @lib.LocalRun::new(1U, @lib.ValType::i32()),
        ]),
        @lib.Expr::new([
          @lib.Instruction::i32_const(41),
          @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        ]),
      ),
    ]),
  )
  .with_name_sec(
    @lib.NameSec::new(
      local_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            0U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::from_string("first")),
              @lib.NameAssoc::new(1U, @lib.Name::from_string("middle")),
              @lib.NameAssoc::new(2U, @lib.Name::from_string("answer")),
            ]),
          ),
        ]),
      ),
    ),
  )
}

///|
test "optimize-instructions groups numeric local declarations and remaps live indices" {
  let input = oi_local_group_parity_fixture()
  assert_true(@validate.validate_module(input).is_ok())
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(locals.runs().length(), 2)
  @debug.assert_eq(locals.get(0), @lib.ValType::i32())
  @debug.assert_eq(locals.get(1), @lib.ValType::i32())
  @debug.assert_eq(locals.get(2), @lib.ValType::f64())
  @debug.assert_eq(body, [
    @lib.Instruction::i32_const(41),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
  @debug.assert_eq(
    output.name_sec.unwrap().local_names.unwrap().0[0],
    @lib.IndirectNameAssoc::new(
      0U,
      @lib.NameMap::new([
        @lib.NameAssoc::new(0U, @lib.Name::from_string("first")),
        @lib.NameAssoc::new(1U, @lib.Name::from_string("answer")),
        @lib.NameAssoc::new(2U, @lib.Name::from_string("middle")),
      ]),
    ),
  )
  assert_eq(
    @binary.encode_module(output).unwrap().length(),
    @binary.encode_module(input).unwrap().length() - 2,
  )
}

///|
test "OI local grouping remaps nested try_table local accesses" {
  let input = oi_local_group_parity_fixture().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_decl_runs_preserving_groups([
          @lib.LocalRun::new(1U, @lib.ValType::i32()),
          @lib.LocalRun::new(1U, @lib.ValType::f64()),
          @lib.LocalRun::new(1U, @lib.ValType::i32()),
        ]),
        @lib.Expr::new([
          @lib.Instruction::try_table(
            @lib.BlockType::void_(),
            [],
            @lib.Expr::new([
              @lib.Instruction::i32_const(41),
              @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            ]),
          ),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        ]),
      ),
    ]),
  )
  assert_true(@validate.validate_module(input).is_ok())
  let output = oi_group_numeric_locals_if_smaller(input)
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(locals.runs().length(), 2)
  match body[0] {
    @lib.TryTable(
      _,
      _,
      @lib.Expr([@lib.I32Const(_), @lib.LocalSet(@lib.LocalIdx(1U))])
    ) => ()
    other => fail("expected remapped try_table local.set, got \{other}")
  }
  @debug.assert_eq(body[1], @lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
}

///|
test "OI local grouping leaves legacy try local indices unchanged" {
  let input = oi_local_group_parity_fixture().with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_decl_runs_preserving_groups([
          @lib.LocalRun::new(1U, @lib.ValType::i32()),
          @lib.LocalRun::new(1U, @lib.ValType::f64()),
          @lib.LocalRun::new(1U, @lib.ValType::i32()),
        ]),
        @lib.Expr::new([
          @lib.Instruction::try_(
            @lib.BlockType::void_(),
            @lib.Expr::new([
              @lib.Instruction::i32_const(41),
              @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            ]),
            [
              @lib.LegacyCatch::all(
                @lib.Expr::new([
                  @lib.Instruction::i32_const(42),
                  @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                ]),
              ),
            ],
          ),
          @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        ]),
      ),
    ]),
  )
  assert_true(@validate.validate_module(input).is_ok())
  @debug.assert_eq(oi_group_numeric_locals_if_smaller(input), input)
}

///|
test "OI local grouping leaves opaque name metadata unchanged" {
  let input = oi_local_group_parity_fixture()
    .without_name_sec()
    .with_raw_name_sec_payload(b"opaque-local-name-map")
  @debug.assert_eq(oi_group_numeric_locals_if_smaller(input), input)
}

///|
test "OI local grouping leaves offset-bearing custom metadata unchanged" {
  for
    name in [
      "metadata.code.branch_hint", "metadata.code.future", ".debug_info", "reloc.CODE",
    ] {
    let input = oi_local_group_parity_fixture().with_custom_secs([
      @lib.CustomSec::new(@lib.Name::from_string(name), b"opaque-code-offsets"),
    ])
    @debug.assert_eq(oi_group_numeric_locals_if_smaller(input), input)
  }
}

///|
test "OI local grouping preserves harmless custom metadata" {
  let input = oi_local_group_parity_fixture().with_custom_secs([
    @lib.CustomSec::new(@lib.Name::from_string("producers"), b"keep"),
  ])
  let output = oi_group_numeric_locals_if_smaller(input)
  assert_false(output.code_sec == input.code_sec)
  @debug.assert_eq(output.custom_secs, input.custom_secs)
}

///|
test "OI local grouping replaces a decoded name section raw cache" {
  let input = oi_local_group_parity_fixture().with_raw_name_sec_payload(
    b"stale-decoded-name-cache",
  )
  let output = run_hot_pipeline_raw_group_body_locals_by_type_module(input)
  assert_false(output.code_sec == input.code_sec)
  @debug.assert_eq(output.raw_name_sec_payload, None)
  @debug.assert_eq(
    output.name_sec.unwrap().local_names.unwrap().0[0],
    @lib.IndirectNameAssoc::new(
      0U,
      @lib.NameMap::new([
        @lib.NameAssoc::new(0U, @lib.Name::from_string("first")),
        @lib.NameAssoc::new(1U, @lib.Name::from_string("answer")),
        @lib.NameAssoc::new(2U, @lib.Name::from_string("middle")),
      ]),
    ),
  )
}

///|
test "OI local grouping clears stale compiler facts and preserves annotations" {
  let facts = @representation.CompilerFactCustomSection::new(
    @representation.OptimizationFactsSec::new(),
  )
  let annotations = @lib.FuncAnnotationSec::new([
    @lib.FuncAnnotationAssoc::new(0U, [
      @lib.FuncAnnotation::new("binaryen.idempotent"),
    ]),
  ])
  let input = oi_local_group_parity_fixture()
    .with_func_annotation_sec(annotations)
    .with_compiler_fact_custom_section(facts)
  let input_bytes = @binary.encode_module(input).unwrap()
  let input_code = input.code_sec
  let input_names = input.name_sec
  let output = oi_group_numeric_locals_if_smaller(input)
  assert_true(@validate.validate_module(output).is_ok())
  @debug.assert_eq(output.compiler_fact_custom_section, None)
  @debug.assert_eq(output.func_annotation_sec, Some(annotations))
  @debug.assert_eq(input.code_sec, input_code)
  @debug.assert_eq(input.name_sec, input_names)
  @debug.assert_eq(input.compiler_fact_custom_section, Some(facts))
  @debug.assert_eq(@binary.encode_module(input).unwrap(), input_bytes)
}

///|
test "OI local grouping excludes compiler fact removal from its size decision" {
  let locals = [@lib.ValType::i64()]
  for _ in 0..<127 {
    locals.push(@lib.ValType::i32())
  }
  locals.push(@lib.ValType::i64())
  let body = []
  for _ in 0..<8 {
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(127U)))
    body.push(@lib.Instruction::drop())
  }
  let input = pass_test_module_from_wat("(module (func))")
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::from_types(locals), @lib.Expr::new(body)),
      ]),
    )
    .with_compiler_fact_custom_section(
      @representation.CompilerFactCustomSection::new(
        @representation.OptimizationFactsSec::new(),
      ),
    )
  assert_true(@validate.validate_module(input).is_ok())
  @debug.assert_eq(oi_group_numeric_locals_if_smaller(input), input)
}
