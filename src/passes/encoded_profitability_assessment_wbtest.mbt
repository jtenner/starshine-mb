///|
fn encoded_profitability_size(mod_ : @lib.Module) -> Int32 {
  @binary.encode_module(mod_).unwrap().length()
}

///|
fn encoded_profitability_local_fixture() -> @lib.Module {
  let body : Array[@lib.Instruction] = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(127U)),
    @lib.Instruction::drop(),
  ]
  for _ in 0..<5 {
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(128U)))
    body.push(@lib.Instruction::drop())
  }
  body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(129U)))
  body.push(@lib.Instruction::drop())
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func(Array::make(127, @lib.ValType::i32()), []),
        ),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([
          @lib.ValType::i32(),
          @lib.ValType::i64(),
          @lib.ValType::i32(),
        ]),
        @lib.Expr::new(body),
      ),
    ]),
  )
}

///|
test "exact local grouping includes index bytes with fixed parameters" {
  let input = encoded_profitability_local_fixture()
  let frequency = reorder_locals_run_module_pass(input)
  let selected = oi_group_numeric_locals_if_smaller(input)
  ignore(@validate.validate_module(input).unwrap())
  ignore(@validate.validate_module(frequency).unwrap())
  ignore(@validate.validate_module(selected).unwrap())
  @debug.assert_eq(encoded_profitability_size(input), 185)
  @debug.assert_eq(encoded_profitability_size(frequency), 179)
  let @lib.Func(locals, @lib.Expr(body)) = frequency.code_sec.unwrap().0[0]
  @debug.assert_eq(locals.length(), 3)
  @debug.assert_eq(locals.runs().length(), 2)
  @debug.assert_eq(
    body[0],
    @lib.Instruction::local_get(@lib.LocalIdx::new(128U)),
  )
  @debug.assert_eq(
    body[2],
    @lib.Instruction::local_get(@lib.LocalIdx::new(127U)),
  )
  assert_true(
    encoded_profitability_size(selected) <=
    encoded_profitability_size(frequency),
    msg="the existing frequency order saves six bytes; first-type grouping saves two",
  )
}

///|
fn encoded_profitability_global_fixture() -> @lib.Module {
  let globals : Array[@lib.Global] = []
  for index in 0..<129 {
    globals.push(
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), false),
        @lib.Expr::new([
          @lib.Instruction::i32_const(
            @lib.I32(
              if index == 128 {
                42
              } else if index == 127 {
                7
              } else {
                0
              },
            ),
          ),
        ]),
      ),
    )
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_global_sec(@lib.GlobalSec::new(globals))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::global_get(@lib.GlobalIdx::new(128U)),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
  .with_name_sec(
    @lib.NameSec::new(
      global_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(127U, @lib.Name::from_string("kept")),
        ]),
      ),
    ),
  )
}

///|
test "exact global order can save bytes without growing the name map" {
  let input = encoded_profitability_global_fixture()
  let selected = reorder_globals_run_module_pass(input)
  let order = rg_identity_order(129)
  order[0] = 128
  order[128] = 0
  let remap = rg_old_abs_to_new_abs(order)
  let profitable = input
    .with_global_sec(
      @lib.GlobalSec::new(
        rg_rewrite_globals(input.global_sec.unwrap().0, order, 0, remap),
      ),
    )
    .with_code_sec(rg_rewrite_code_sec(input.code_sec, remap).unwrap())
    .with_name_sec(rg_rewrite_name_sec(input.name_sec, remap).unwrap())
  ignore(@validate.validate_module(input).unwrap())
  ignore(@validate.validate_module(selected).unwrap())
  ignore(@validate.validate_module(profitable).unwrap())
  @debug.assert_eq(encoded_profitability_size(input), 694)
  @debug.assert_eq(encoded_profitability_size(profitable), 693)
  @debug.assert_eq(
    profitable.name_sec.unwrap().global_names,
    input.name_sec.unwrap().global_names,
  )
  let @lib.Func(_, @lib.Expr(body)) = profitable.code_sec.unwrap().0[0]
  @debug.assert_eq(
    body[0],
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
  )
  @debug.assert_eq(
    profitable.global_sec.unwrap().0[0],
    input.global_sec.unwrap().0[128],
  )
  assert_true(
    encoded_profitability_size(selected) <=
    encoded_profitability_size(profitable),
    msg="swapping the hot global with unused global zero saves one whole-module byte",
  )
}

///|
test "size policy keeps scalar splats when a vector literal costs more" {
  for value in [0, 63, 64, -64, -65, 2147483647] {
    let source = "(module (func (result v128) i32.const \{value} i32x4.splat))"
    let input = pass_test_module_from_wat(source)
    let selected = pass_test_run_pipeline(
      source,
      ["precompute"],
      options=HotPipelineOptions::new(shrink_level=1),
    ).unwrap()
    ignore(@validate.validate_module(selected).unwrap())
    let input_size = encoded_profitability_size(input)
    // A scalar i32 constant costs 2..6 bytes; the SIMD splat costs two.
    // The same vector in v128.const costs eighteen bytes.
    @debug.assert_eq(
      input_size,
      if value == 2147483647 {
        33
      } else if value == 64 || value == -65 {
        30
      } else {
        29
      },
    )
    assert_true(
      encoded_profitability_size(selected) <= input_size,
      msg="a vector literal must not replace a smaller scalar splat under size policy",
    )
    let again = run_hot_pipeline(
      selected,
      HotPipelineOptions::new(shrink_level=1),
      ["precompute"],
    ).unwrap()
    @debug.assert_eq(
      @binary.encode_module(again),
      @binary.encode_module(selected),
    )
  }
}

///|
test "default precompute keeps its existing vector literal policy" {
  let selected = pass_test_run_pipeline(
    "(module (func (result v128) i32.const 0 i32x4.splat))",
    ["precompute"],
  ).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = selected.code_sec.unwrap().0[0]
  @debug.assert_eq(body.length(), 1)
  @debug.assert_eq(
    precompute_v128_const_bytes(body[0]),
    Some(Array::make(16, b'\x00')),
  )
}

///|
test "size policy materializes vectors after scalar consumers fold" {
  for
    source in [
      "(module (func (result i32) i32.const 3 i32x4.splat i32x4.extract_lane 2))",
      "(module (func (result i32) i32.const 0 i32x4.splat v128.any_true))",
    ] {
    let selected = pass_test_run_pipeline(
      source,
      ["precompute"],
      options=HotPipelineOptions::new(shrink_level=1),
    ).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = selected.code_sec.unwrap().0[0]
    @debug.assert_eq(body.length(), 1)
    assert_true(body[0] is @lib.I32Const(_))
    ignore(@validate.validate_module(selected).unwrap())
  }
}

///|
test "size policy preserves vector NaN payloads and signed zero bit for bit" {
  for lane in [0U, 0x80000000U, 0x7fc00001U, 0x7fa12345U, 0xffffffffU] {
    let bytes = Array::make(16, b'\x00')
    for offset in [0, 4, 8, 12] {
      precompute_v128_write_u32(bytes, offset, lane)
    }
    let literal = precompute_v128_const_from_bytes(bytes).unwrap()
    let input = pass_test_module_from_wat(
      "(module (func (result v128) v128.const i32x4 0 0 0 0))",
    ).with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::v128()),
              @lib.Expr::new([literal]),
            ),
          ]),
        ),
      ]),
    )
    let selected = run_hot_pipeline(
      input,
      HotPipelineOptions::new(shrink_level=1),
      ["precompute"],
    ).unwrap()
    let restored = run_hot_pipeline(selected, HotPipelineOptions::new(), [
      "precompute",
    ]).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = restored.code_sec.unwrap().0[0]
    @debug.assert_eq(body.length(), 1)
    @debug.assert_eq(precompute_v128_const_bytes(body[0]), Some(bytes))
    assert_true(
      encoded_profitability_size(selected) <
      encoded_profitability_size(restored),
    )
    ignore(@validate.validate_module(selected).unwrap())
  }
}

///|
test "local candidates preserve touched functions and opaque metadata" {
  let input = encoded_profitability_local_fixture()
  for
    protected in [
      input.with_raw_name_sec_payload(b"opaque-name"),
      input.with_custom_secs([
        @lib.CustomSec::new(@lib.Name::new("reloc.CODE"), b"\x00"),
      ]),
      input.with_custom_secs([
        @lib.CustomSec::new(
          @lib.Name::new("metadata.code.branch_hint"),
          b"\x00",
        ),
      ]),
    ] {
    @debug.assert_eq(
      @binary.encode_module(oi_group_numeric_locals_if_smaller(protected)),
      @binary.encode_module(protected),
    )
  }
  @debug.assert_eq(
    @binary.encode_module(
      oi_group_numeric_locals_if_smaller(input, touched=Some([false])),
    ),
    @binary.encode_module(input),
  )
}

///|
test "global candidates remap decoded names clear stale raw names and protect metadata" {
  let input = encoded_profitability_global_fixture()
  let raw_input = input
    .without_name_sec()
    .with_raw_name_sec_payload(b"stale-global-index-name-payload")
  let raw_selected = reorder_globals_run_module_pass(raw_input)
  @debug.assert_eq(raw_selected.raw_name_sec_payload, None)
  @debug.assert_eq(raw_selected.name_sec, None)
  let @lib.Func(_, @lib.Expr(raw_body)) = raw_selected.code_sec.unwrap().0[0]
  @debug.assert_eq(
    raw_body[0],
    @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
  )
  @debug.assert_eq(
    raw_selected.global_sec.unwrap().0[0],
    input.global_sec.unwrap().0[128],
  )
  let decoded = reorder_globals_run_module_pass(input)
  @debug.assert_eq(
    decoded.name_sec.unwrap().global_names,
    input.name_sec.unwrap().global_names,
  )
  let stale_with_decoded = reorder_globals_run_module_pass(
    input.with_raw_name_sec_payload(b"stale-global-index-name-payload"),
  )
  @debug.assert_eq(stale_with_decoded.raw_name_sec_payload, None)
  @debug.assert_eq(
    stale_with_decoded.name_sec.unwrap().global_names,
    input.name_sec.unwrap().global_names,
  )
  for
    protected in [
      input.with_custom_secs([
        @lib.CustomSec::new(@lib.Name::new("linking"), b"\x00"),
      ]),
      input.with_custom_secs([
        @lib.CustomSec::new(@lib.Name::new(".debug_info"), b"\x00"),
      ]),
    ] {
    @debug.assert_eq(
      @binary.encode_module(reorder_globals_run_module_pass(protected)),
      @binary.encode_module(protected),
    )
  }
}

///|
test "size policy leaves nonuniform vector literals unchanged" {
  let source = "(module (func (result v128) v128.const i32x4 1 2 3 4))"
  let input = pass_test_module_from_wat(source)
  let selected = pass_test_run_pipeline(
    source,
    ["precompute"],
    options=HotPipelineOptions::new(shrink_level=1),
  ).unwrap()
  @debug.assert_eq(
    @binary.encode_module(selected),
    @binary.encode_module(input),
  )
}

///|
test "size policy supports every scalar splat without blocking the next fold" {
  for
    source in [
      "(module (func (result v128) i32.const 1234 i16x8.splat))", "(module (func (result v128) i64.const 9223372036854775807 i64x2.splat))",
      "(module (func (result v128) f32.const -0 f32x4.splat))", "(module (func (result v128) f64.const nan:0x12345 f64x2.splat))",
    ] {
    let literal = pass_test_run_pipeline(source, ["precompute"]).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = literal.code_sec.unwrap().0[0]
    @debug.assert_eq(body.length(), 1)
    let expected = precompute_v128_const_bytes(body[0]).unwrap()
    let selected = pass_test_run_pipeline(
      source,
      ["precompute"],
      options=HotPipelineOptions::new(shrink_level=1),
    ).unwrap()
    assert_true(
      encoded_profitability_size(selected) < encoded_profitability_size(literal),
    )
    let restored = run_hot_pipeline(selected, HotPipelineOptions::new(), [
      "precompute",
    ]).unwrap()
    let @lib.Func(_, @lib.Expr(restored_body)) = restored.code_sec.unwrap().0[0]
    @debug.assert_eq(
      precompute_v128_const_bytes(restored_body[0]),
      Some(expected),
    )
    let again = run_hot_pipeline(
      selected,
      HotPipelineOptions::new(shrink_level=1),
      ["precompute"],
    ).unwrap()
    @debug.assert_eq(
      @binary.encode_module(again),
      @binary.encode_module(selected),
    )
    ignore(@validate.validate_module(selected).unwrap())
  }
}

///|
test "global size candidates retain initializer dependency order" {
  let input = encoded_profitability_global_fixture()
  let globals = input.global_sec.unwrap().0.copy()
  globals[128] = @lib.Global::new(
    @lib.GlobalType::new(@lib.ValType::i32(), false),
    @lib.Expr::new([@lib.Instruction::global_get(@lib.GlobalIdx::new(127U))]),
  )
  let input = input.with_global_sec(@lib.GlobalSec::new(globals))
  ignore(@validate.validate_module(input).unwrap())
  let selected = reorder_globals_run_module_pass(input)
  ignore(@validate.validate_module(selected).unwrap())
  let globals = selected.global_sec.unwrap().0
  for index in 0..<globals.length() {
    let @lib.Global(_, @lib.Expr(init)) = globals[index]
    for instr in init {
      if instr is @lib.GlobalGet(@lib.GlobalIdx(raw)) {
        assert_true(raw.to_int() < index)
      }
    }
  }
  assert_true(
    encoded_profitability_size(selected) <= encoded_profitability_size(input),
  )
}

///|
test "global exact name costs reject an index-only saving" {
  let input = encoded_profitability_global_fixture().with_name_sec(
    @lib.NameSec::new(
      global_names=Some(
        @lib.NameMap::new(
          Array::makei(128, fn(index) {
            @lib.NameAssoc::new(index.to_uint(), @lib.Name::new("kept"))
          }),
        ),
      ),
    ),
  )
  let selected = reorder_globals_run_module_pass(input)
  @debug.assert_eq(
    @binary.encode_module(selected),
    @binary.encode_module(input),
  )
}

///|
test "global name-only traffic can cross an index-width boundary profitably" {
  let input = encoded_profitability_global_fixture()
    .with_global_sec(
      @lib.GlobalSec::new(
        Array::makei(129, fn(_) {
          @lib.Global::new(
            @lib.GlobalType::new(@lib.ValType::i32(), false),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(42))]),
          )
        }),
      ),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    )
    .with_name_sec(
      @lib.NameSec::new(
        global_names=Some(
          @lib.NameMap::new([@lib.NameAssoc::new(128U, @lib.Name::new("kept"))]),
        ),
      ),
    )
  ignore(@validate.validate_module(input).unwrap())
  let order = rg_identity_order(129)
  order[0] = 128
  order[128] = 0
  let profitable = rg_apply_order(input, input.global_sec.unwrap().0, order, 0)
  @debug.assert_eq(encoded_profitability_size(input), 691)
  @debug.assert_eq(encoded_profitability_size(profitable), 690)
  let selected = reorder_globals_run_module_pass(input)
  assert_true(
    encoded_profitability_size(selected) < encoded_profitability_size(input),
  )
  @debug.assert_eq(
    selected.name_sec.unwrap().global_names,
    profitable.name_sec.unwrap().global_names,
  )
  @debug.assert_eq(selected.global_sec.unwrap().0, input.global_sec.unwrap().0)
  @debug.assert_eq(selected.code_sec, input.code_sec)
  ignore(@validate.validate_module(selected).unwrap())
}

///|
test "vector materialization retains scalar and nested control identity" {
  let scalar = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0))",
  )
  let bt = @lib.BlockType::val_type(@lib.ValType::i32())
  let nested = scalar.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::block(
            bt,
            @lib.Expr::new([
              @lib.Instruction::loop_(
                bt,
                @lib.Expr::new([
                  @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                  @lib.Instruction::if_(
                    bt,
                    [
                      @lib.Instruction::try_(
                        bt,
                        @lib.Expr::new([
                          @lib.Instruction::i32_const(@lib.I32(11)),
                        ]),
                        [
                          @lib.LegacyCatch::all(
                            @lib.Expr::new([
                              @lib.Instruction::i32_const(@lib.I32(12)),
                            ]),
                          ),
                        ],
                      ),
                    ],
                    Some([
                      @lib.Instruction::try_table(
                        bt,
                        [],
                        @lib.Expr::new([
                          @lib.Instruction::i32_const(@lib.I32(13)),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ]),
  )
  for input in [scalar, nested] {
    ignore(@validate.validate_module(input).unwrap())
    let before = @binary.encode_module(input).unwrap()
    let selected = precompute_materialize_vectors_for_size(input, 1)
    assert_true(physical_equal(selected, input))
    assert_true(
      physical_equal(
        selected.code_sec.unwrap().0[0],
        input.code_sec.unwrap().0[0],
      ),
    )
    @debug.assert_eq(@binary.encode_module(selected).unwrap(), before)
  }
}

///|
test "vector materialization keeps offset metadata and default policy" {
  let input = pass_test_module_from_wat(
    "(module (func (result v128) v128.const i32x4 0 0 0 0))",
  )
  for
    protected in [
      input.with_custom_secs([
        @lib.CustomSec::new(
          @lib.Name::new("metadata.code.branch_hint"),
          b"\x00",
        ),
      ]),
      input.with_custom_secs([
        @lib.CustomSec::new(@lib.Name::new("reloc.CODE"), b"\x00"),
      ]),
      input.with_custom_secs([
        @lib.CustomSec::new(@lib.Name::new(".debug_info"), b"\x00"),
      ]),
    ] {
    assert_true(
      physical_equal(
        precompute_materialize_vectors_for_size(protected, 1),
        protected,
      ),
    )
    @debug.assert_eq(
      @binary.encode_module(
        precompute_materialize_vectors_for_size(protected, 1),
      ),
      @binary.encode_module(protected),
    )
  }
  assert_true(
    physical_equal(precompute_materialize_vectors_for_size(input, 0), input),
  )
}

///|
test "local size candidates retain functions with no body locals" {
  for count in [0, 129] {
    let input = encoded_profitability_local_fixture()
      .with_type_sec(
        @lib.TypeSec::new([
          @lib.RecType::new(
            @lib.SubType::comp_type(
              @lib.CompType::func(Array::make(count, @lib.ValType::i32()), []),
            ),
          ),
        ]),
      )
      .with_code_sec(
        @lib.CodeSec::new([
          @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        ]),
      )
      .with_name_sec(
        @lib.NameSec::new(module_name=Some(@lib.Name::new("kept"))),
      )
      .with_compiler_fact_custom_section(
        @representation.CompilerFactCustomSection::new(
          @representation.OptimizationFactsSec::new(),
        ),
      )
    let before = @binary.encode_module(input).unwrap()
    let selected = oi_group_numeric_locals_if_smaller(input)
    assert_true(physical_equal(selected, input))
    @debug.assert_eq(@binary.encode_module(selected).unwrap(), before)
    @debug.assert_eq(
      selected.compiler_fact_custom_section,
      input.compiler_fact_custom_section,
    )
  }
}
