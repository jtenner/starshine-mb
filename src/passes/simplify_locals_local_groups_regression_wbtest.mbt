///|
fn sl_local_groups_run(
  input : @lib.Module,
  pass_name : String,
) -> @lib.Module raise {
  run_hot_pipeline(input, HotPipelineOptions::new(), [pass_name]).unwrap()
}

///|
fn sl_local_groups_roundtrip(input : @lib.Module) -> @lib.Module raise {
  ignore(@validate.validate_module(input).unwrap())
  let output = @binary.decode_module(@binary.encode_module(input).unwrap()).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  output
}

///|
fn sl_local_groups_structure_fixture(parameter : Bool) -> @lib.Module {
  let layouts = if parameter {
    [
      "i32 i32 i32 i32 i32 f64 i32 f64 f64 f64 i64 f32", "i32 i32 i32 i32 i32 i64 f32 f64",
      "i32 i32 i32 i32 i32 f32 i32 i64 f64", "i32 i32 i32 i32 i32 i32 i64 f32 f32 i64 f32 f64",
    ]
  } else {
    [
      "i32 i32 i32 i32 i32 i64 f32 f64", "i32 i32 i32 i32 i32 f64 i32 f64 i64 f32",
    ]
  }
  let index = if parameter { 1 } else { 0 }
  let mut text = if parameter {
    "(module (type (func (param f32))) (type (func)) (export \"main\" (func 0)) "
  } else {
    "(module (type (func)) (export \"main\" (func 0)) "
  }
  for layout in layouts {
    text += "(func (type 0) " +
      (if parameter { "(param f32) " } else { "" }) +
      "(local " +
      layout +
      ") i32.const 1 if i32.const 61 local.set " +
      index.to_string() +
      " else i32.const 62 local.set " +
      index.to_string() +
      " end local.get " +
      index.to_string() +
      " drop block i32.const 63 local.set " +
      (index + 1).to_string() +
      " end local.get " +
      (index + 1).to_string() +
      " drop) "
  }
  pass_test_module_from_wat(text + ")")
}

///|
// No floating/reference value is read by this fixture executor. Validation
// checks those declaration types; all executed accesses are i32.
fn sl_local_groups_observe(
  func : @lib.Func,
  parameter_count : Int32,
  value : Int32,
) -> (Int32, Array[Int32]) raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = Array::make(parameter_count + body_locals.length(), 0)
  if parameter_count > 0 {
    locals[0] = value
  }
  let stack : Array[Int32] = []
  let events : Array[Int32] = []
  let mut fuel = 256
  fn execute(instructions : Array[@lib.Instruction]) -> Unit raise {
    for instruction in instructions {
      fuel -= 1
      assert_true(fuel > 0)
      match instruction {
        @lib.Nop => ()
        @lib.Drop => ignore(stack.pop().unwrap())
        @lib.I32Const(@lib.I32(value)) => stack.push(value)
        @lib.LocalGet(@lib.LocalIdx(index)) =>
          stack.push(locals[index.to_int()])
        @lib.LocalSet(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack.pop().unwrap()
        @lib.LocalTee(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack[stack.length() - 1]
        @lib.I32Add => {
          let right = stack.pop().unwrap()
          stack.push(stack.pop().unwrap() + right)
        }
        @lib.Call(index) => {
          assert_eq(index, @lib.FuncIdx::new(0U))
          events.push(stack[stack.length() - 1])
        }
        @lib.Block(_, @lib.Expr(nested)) | @lib.Loop(_, @lib.Expr(nested)) =>
          execute(nested)
        @lib.Try(_, @lib.Expr(nested), _, _) => execute(nested)
        _ => fail("unsupported local-group instruction: \{instruction}")
      }
    }
  }
  execute(body)
  assert_eq(stack.length(), 1)
  (stack[0], events)
}

///|
fn sl_local_groups_accesses(
  body : Array[@lib.Instruction],
) -> Array[(@lib.Instruction, UInt32)] {
  let accesses : Array[(@lib.Instruction, UInt32)] = []
  fn visit(instructions : Array[@lib.Instruction]) -> Unit {
    for instruction in instructions {
      match instruction {
        @lib.LocalGet(@lib.LocalIdx(index))
        | @lib.LocalSet(@lib.LocalIdx(index))
        | @lib.LocalTee(@lib.LocalIdx(index)) =>
          accesses.push((instruction, index))
        @lib.Block(_, @lib.Expr(nested)) | @lib.Loop(_, @lib.Expr(nested)) =>
          visit(nested)
        @lib.If(_, yes, no) => {
          visit(yes)
          visit(no.or([]))
        }
        @lib.Try(_, @lib.Expr(nested), _, _) => visit(nested)
        _ => ()
      }
    }
  }
  visit(body)
  accesses
}

///|
fn sl_local_groups_live_fixture(
  types : Array[@lib.ValType],
  target : UInt32,
) -> @lib.Module {
  pass_test_module_from_wat(
    "(module (import \"host\" \"mark\" (func (param i32) (result i32))) " +
    "(func (export \"run\") (param i32) (result i32) (local i32) local.get 0))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types(types),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(target)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(target)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(target)),
          @lib.Instruction::i32_add(),
        ]),
      ),
    ]),
  )
}

///|
fn sl_local_groups_check_retained_gap(parameter : Bool) -> Unit raise {
  // Exact retained cases2/11, with160/92B full-SL output before grouping.
  // Numeric declarations alone must save10/4B against133's151/90B.
  let input = sl_local_groups_roundtrip(
    sl_local_groups_structure_fixture(parameter),
  )
  let before = input.code_sec.unwrap().0
  for pass_name in ["simplify-locals", "simplify-locals-nostructure"] {
    let output = sl_local_groups_roundtrip(
      sl_local_groups_run(input, pass_name),
    )
    let after = output.code_sec.unwrap().0
    assert_eq(after.length(), before.length())
    let ungrouped = after.mapi(fn(index, func) {
      let @lib.Func(old_locals, _) = before[index]
      let @lib.Func(locals, body) = func
      assert_eq(locals.length(), old_locals.length())
      assert_eq(locals.runs().length(), 4)
      // Both source locals accessed by the surviving body are in the fixed
      // initial i32 run, so restoring declaration order remains well typed.
      @lib.Func::new(old_locals, body)
    })
    let same_body_ungrouped = output.with_code_sec(@lib.CodeSec::new(ungrouped))
    ignore(@validate.validate_module(same_body_ungrouped).unwrap())
    let bytes = @binary.encode_module(output).unwrap().length()
    let old_bytes = @binary.encode_module(same_body_ungrouped).unwrap().length()
    assert_true(bytes < old_bytes)
    let mut declaration_saving = 0
    for index, func in after {
      let @lib.Func(old_locals, _) = before[index]
      let @lib.Func(locals, _) = func
      let old_decl = @buffer.new()
      let next_decl = @buffer.new()
      @binary.Encode::encode(old_locals, old_decl).unwrap()
      @binary.Encode::encode(locals, next_decl).unwrap()
      declaration_saving += old_decl.length() - next_decl.length()
    }
    assert_eq(declaration_saving, if parameter { 10 } else { 4 })
    // A code-section length LEB can shrink as well as its declarations.
    assert_true(old_bytes - bytes >= declaration_saving)
    // The public pass result retains Nops for the final writer. The command
    // regression checks the complete151/90B oracle bounds after that writer;
    // this boundary checks the exact10/4B declaration saving on the same body.
  }
}

///|
test "simplify-locals local groups save declaration bytes for retained case2 shape" {
  sl_local_groups_check_retained_gap(true)
}

///|
test "simplify-locals local groups save declaration bytes for retained case11 shape" {
  sl_local_groups_check_retained_gap(false)
}

///|
fn sl_local_groups_named_fixture() -> @lib.Module {
  pass_test_module_from_wat(
    "(module (import \"host\" \"mark\" (func (param i32) (result i32))) " +
    "(func (export \"run\") (param i32 i64) (result i32) (local i32 f64 i32 f64) " +
    "local.get 0 call 0 local.set 4 local.get 4 local.get 4 i32.add) " +
    "(func (result i32) i32.const 9))",
  ).with_name_sec(
    @lib.NameSec::new(
      local_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            0U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(
                0U,
                @lib.Name::from_string("imported-argument"),
              ),
            ]),
          ),
          @lib.IndirectNameAssoc::new(
            1U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(
                0U,
                @lib.Name::from_string("fixed-i32-parameter"),
              ),
              @lib.NameAssoc::new(
                1U,
                @lib.Name::from_string("fixed-i64-parameter"),
              ),
              @lib.NameAssoc::new(
                2U,
                @lib.Name::from_string("first-i32-body-local"),
              ),
              @lib.NameAssoc::new(
                3U,
                @lib.Name::from_string("first-f64-body-local-with-a-long-name"),
              ),
              @lib.NameAssoc::new(
                4U,
                @lib.Name::from_string(
                  "observable-i32-body-local-with-a-long-name",
                ),
              ),
              @lib.NameAssoc::new(
                5U,
                @lib.Name::from_string("last-f64-body-local"),
              ),
            ]),
          ),
        ]),
      ),
    ),
  )
}

///|
test "simplify-locals local groups remap live indices and decoded names after fixed parameters" {
  let input = sl_local_groups_roundtrip(sl_local_groups_named_fixture())
  assert_true(input.raw_name_sec_payload is Some(_))
  let saved = @binary.encode_module(input).unwrap()
  for pass_name in ["simplify-locals", "simplify-locals-nostructure"] {
    let output = sl_local_groups_roundtrip(
      sl_local_groups_run(input, pass_name),
    )
    let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    assert_eq(locals.runs().length(), 2)
    assert_eq(Array::makei(locals.length(), fn(index) { locals.get(index) }), [
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::f64(),
      @lib.ValType::f64(),
    ])
    let accesses = sl_local_groups_accesses(body)
    assert_true(
      accesses.any(fn(access) {
        access.0 is @lib.LocalTee(_) || access.0 is @lib.LocalSet(_)
      }),
    )
    assert_true(accesses.any(fn(access) { access.1 == 3U }))
    assert_true(accesses.all(fn(access) { access.1 == 0U || access.1 == 3U }))
    let maps = output.name_sec.unwrap().local_names.unwrap().0
    assert_eq(maps[0], input.name_sec.unwrap().local_names.unwrap().0[0])
    let @lib.IndirectNameAssoc(function_index, @lib.NameMap(names)) = maps[1]
    assert_eq(function_index, 1U)
    let old_names = input.name_sec.unwrap().local_names.unwrap().0[1].1.0
    assert_eq(names, [
      old_names[0],
      old_names[1],
      old_names[2],
      @lib.NameAssoc::new(3U, old_names[4].1),
      @lib.NameAssoc::new(4U, old_names[3].1),
      old_names[5],
    ])
    assert_eq(output.code_sec.unwrap().0[1], input.code_sec.unwrap().0[1])
    for value in [-7, 0, 10] {
      assert_eq(
        sl_local_groups_observe(output.code_sec.unwrap().0[0], 2, value),
        (value + value, [value]),
      )
    }
  }
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "simplify-locals local groups retain already grouped numeric and reference declarations" {
  for
    (types, target) in [
      ([@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()], 3U),
      ([@lib.ValType::i32(), @lib.ValType::f64(), @lib.ValType::i64()], 1U),
      (
        [@lib.ValType::i32(), @lib.ValType::externref(), @lib.ValType::i32()],
        3U,
      ),
    ] {
    let input = sl_local_groups_roundtrip(
      sl_local_groups_live_fixture(types, target),
    )
    for pass_name in ["simplify-locals", "simplify-locals-nostructure"] {
      let output = sl_local_groups_roundtrip(
        sl_local_groups_run(input, pass_name),
      )
      let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
      assert_eq(
        Array::makei(locals.length(), fn(index) { locals.get(index) }),
        types,
      )
      assert_eq(
        sl_local_groups_observe(output.code_sec.unwrap().0[0], 1, 11),
        (22, [11]),
      )
    }
  }
}

///|
test "simplify-locals local groups intentionally retain opaque raw-name-only index order" {
  // Raw-name-only Module IR is intentionally unsupported by the remapper.
  // It has no legal round trip through Encode(Module), which only writes raw
  // name bytes alongside a decoded NameSec. Do not fabricate an invalid wasm.
  let input = sl_local_groups_live_fixture(
      [
        @lib.ValType::i32(),
        @lib.ValType::f64(),
        @lib.ValType::i32(),
        @lib.ValType::f64(),
      ],
      3U,
    )
    .without_name_sec()
    .with_raw_name_sec_payload(b"opaque-local-name-map")
  ignore(@validate.validate_module(input).unwrap())
  for pass_name in ["simplify-locals", "simplify-locals-nostructure"] {
    let output = sl_local_groups_run(input, pass_name)
    ignore(@validate.validate_module(output).unwrap())
    let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
    assert_eq(locals, sl_local_groups_body_decls(input.code_sec.unwrap().0[0]))
    assert_eq(
      sl_local_groups_observe(output.code_sec.unwrap().0[0], 1, 11),
      (22, [11]),
    )
  }
}

///|
test "simplify-locals local groups intentionally retain offset metadata index order" {
  // These metadata families are intentionally unsupported by local remapping.
  for
    name in [
      "metadata.code.branch_hint", "reloc.CODE", "linking", "sourceMappingURL", "external_debug_info",
      ".debug_info",
    ] {
    let input = sl_local_groups_live_fixture(
      [
        @lib.ValType::i32(),
        @lib.ValType::f64(),
        @lib.ValType::i32(),
        @lib.ValType::f64(),
      ],
      3U,
    ).with_custom_secs([
      @lib.CustomSec::new(@lib.Name::from_string(name), b"opaque-code-offsets"),
    ])
    let input = sl_local_groups_roundtrip(input)
    for pass_name in ["simplify-locals", "simplify-locals-nostructure"] {
      let output = sl_local_groups_roundtrip(
        sl_local_groups_run(input, pass_name),
      )
      let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
      assert_eq(
        locals,
        sl_local_groups_body_decls(input.code_sec.unwrap().0[0]),
      )
      assert_eq(output.custom_secs, input.custom_secs)
      assert_eq(
        sl_local_groups_observe(output.code_sec.unwrap().0[0], 1, 11),
        (22, [11]),
      )
    }
  }
}

///|
test "simplify-locals local groups do not grow complete encoding at local index LEB boundaries" {
  for count in [127, 128, 129] {
    let types = [@lib.ValType::i64()]
    for _ in 0..<(count - 3) {
      types.push(@lib.ValType::i32())
    }
    types.push(@lib.ValType::i64())
    let target = (count - 2).to_uint()
    let body = [
      @lib.Instruction::i32_const(7),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(target)),
    ]
    for _ in 0..<8 {
      body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(target)))
      body.push(@lib.Instruction::call(@lib.FuncIdx::new(0U)))
      body.push(@lib.Instruction::drop())
    }
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(target)))
    let input = sl_local_groups_live_fixture(types, 1U).with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::from_types(types), @lib.Expr::new(body)),
      ]),
    )
    let input = sl_local_groups_roundtrip(input)
    assert_eq(
      sl_local_groups_body_decls(input.code_sec.unwrap().0[0]).length() + 1,
      count,
    )
    let before = @binary.encode_module(input).unwrap().length()
    for pass_name in ["simplify-locals", "simplify-locals-nostructure"] {
      let output = sl_local_groups_roundtrip(
        sl_local_groups_run(input, pass_name),
      )
      assert_true(
        @binary.encode_module(output).unwrap().length() <= before,
        msg="decl savings must include local-index and body/section LEB costs",
      )
      assert_eq(
        sl_local_groups_observe(output.code_sec.unwrap().0[0], 1, 0),
        (7, Array::make(9, 7)),
      )
    }
  }
}

///|
test "simplify-locals declaration grouping retains named unused locals above index 128" {
  let types = Array::make(128, @lib.ValType::i32())
  types.append([@lib.ValType::f64(), @lib.ValType::i32(), @lib.ValType::f64()])
  let names = @lib.NameMap::new([
    @lib.NameAssoc::new(1U, @lib.Name::from_string("unused-i32")),
    @lib.NameAssoc::new(129U, @lib.Name::from_string("unused-f64")),
    @lib.NameAssoc::new(130U, @lib.Name::from_string("live-i32")),
  ])
  let input = sl_local_groups_roundtrip(
    sl_local_groups_live_fixture(types, 130U).with_name_sec(
      @lib.NameSec::new(
        local_names=Some(
          @lib.IndirectNameMap::new([@lib.IndirectNameAssoc::new(1U, names)]),
        ),
      ),
    ),
  )
  for
    pass_name in [
      "simplify-locals", "simplify-locals-nostructure", "simplify-locals-no-structure",
    ] {
    let output = sl_local_groups_roundtrip(
      sl_local_groups_run(input, pass_name),
    )
    let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
    assert_eq(locals.length(), 131)
    let @lib.IndirectNameAssoc(_, @lib.NameMap(after_names)) = output.name_sec.unwrap().local_names.unwrap().0[0]
    assert_eq(after_names.length(), 3)
    for @lib.NameAssoc(index, name) in after_names {
      let expected_type = if name == @lib.Name::from_string("unused-f64") {
        @lib.ValType::f64()
      } else {
        @lib.ValType::i32()
      }
      assert_eq(locals.get(index.to_int() - 1), expected_type)
    }
    for value in [-7, 0, 10] {
      assert_eq(
        sl_local_groups_observe(output.code_sec.unwrap().0[0], 1, value),
        (value + value, [value]),
      )
    }
    assert_true(
      @binary.encode_module(output).unwrap().length() <=
      @binary.encode_module(input).unwrap().length(),
    )
  }
}

///|
test "simplify-locals local groups intentionally retain legacy EH index order" {
  // Shared local grouping deliberately excludes legacy EH remapping.
  let input = sl_local_groups_live_fixture(
    [
      @lib.ValType::i32(),
      @lib.ValType::f64(),
      @lib.ValType::i32(),
      @lib.ValType::f64(),
    ],
    3U,
  )
  let @lib.Func(locals, _) = input.code_sec.unwrap().0[0]
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        locals,
        @lib.Expr::new([
          @lib.Instruction::try_(
            @lib.BlockType::val_type(@lib.ValType::i32()),
            @lib.Expr::new([
              @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
              @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            ]),
            [
              @lib.LegacyCatch::all(
                @lib.Expr::new([@lib.Instruction::i32_const(5)]),
              ),
            ],
          ),
          @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
          @lib.Instruction::i32_add(),
        ]),
      ),
    ]),
  )
  let input = sl_local_groups_roundtrip(input)
  for pass_name in ["simplify-locals", "simplify-locals-nostructure"] {
    let output = sl_local_groups_roundtrip(
      sl_local_groups_run(input, pass_name),
    )
    assert_eq(sl_local_groups_body_decls(output.code_sec.unwrap().0[0]), locals)
    assert_eq(
      sl_local_groups_observe(output.code_sec.unwrap().0[0], 1, 11),
      (22, [11]),
    )
  }
}

///|
fn sl_local_groups_body_decls(func : @lib.Func) -> @lib.Locals {
  let @lib.Func(locals, _) = func
  locals
}
