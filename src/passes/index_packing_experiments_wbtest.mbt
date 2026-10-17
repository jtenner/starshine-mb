///|
fn index_packing_size(mod_ : @lib.Module) -> Int32 {
  @binary.encode_module(mod_).unwrap().length()
}

///|
test "global exact packing combines independent name-only boundary wins" {
  let input = @lib.Module::new()
    .with_global_sec(
      @lib.GlobalSec::new(
        Array::makei(130, fn(index) {
          @lib.Global::new(
            @lib.GlobalType::new(@lib.ValType::i32(), false),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(index))]),
          )
        }),
      ),
    )
    .with_name_sec(
      @lib.NameSec::new(
        global_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(128U, @lib.Name::new("first")),
            @lib.NameAssoc::new(129U, @lib.Name::new("second")),
          ]),
        ),
      ),
    )
  ignore(@validate.validate_module(input).unwrap())
  let selected = reorder_globals_run_module_pass(input)
  ignore(@validate.validate_module(selected).unwrap())
  @debug.assert_eq(index_packing_size(input), 756)
  @debug.assert_eq(index_packing_size(selected), 754)
  let names = selected.name_sec.unwrap().global_names.unwrap().0
  for entry in names {
    let @lib.NameAssoc(index, name) = entry
    assert_true(index < 128U)
    let @lib.Global(_, @lib.Expr(init)) = selected.global_sec.unwrap().0[index.to_int()]
    @debug.assert_eq(init, [
      @lib.Instruction::i32_const(
        @lib.I32(if name == @lib.Name::new("first") { 128 } else { 129 }),
      ),
    ])
  }
  @debug.assert_eq(
    @binary.encode_module(reorder_globals_run_module_pass(selected)),
    @binary.encode_module(selected),
  )
}

///|
test "combined global packing preserves imported ABI and initializer dependencies" {
  let cold = Array::make(127, "(global i32 (i32.const 0))").join("\n")
  let input = pass_test_module_from_wat(
    "(module (import \"host\" \"fixed\" (global i32)) \{cold} (global i32 (i32.const 128)) (global i32 (i32.const 129)) (global i32 (global.get 128)))",
  ).with_name_sec(
    @lib.NameSec::new(
      global_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(128U, @lib.Name::new("first")),
          @lib.NameAssoc::new(129U, @lib.Name::new("second")),
        ]),
      ),
    ),
  )
  ignore(@validate.validate_module(input).unwrap())
  let selected = reorder_globals_run_module_pass(input)
  ignore(@validate.validate_module(selected).unwrap())
  @debug.assert_eq(selected.import_sec, input.import_sec)
  @debug.assert_eq(index_packing_size(selected), index_packing_size(input) - 3)
  let mut references = 0
  for defined, global in selected.global_sec.unwrap().0 {
    for instruction in global.1.0 {
      if instruction is @lib.GlobalGet(@lib.GlobalIdx(index)) {
        references += 1
        assert_true(index.to_int() < defined + 1)
        let @lib.Global(_, @lib.Expr(init)) = selected.global_sec.unwrap().0[index.to_int() -
          1]
        @debug.assert_eq(init, [@lib.Instruction::i32_const(@lib.I32(128))])
      }
    }
  }
  @debug.assert_eq(references, 1)
  for name in ["reloc.CODE", "metadata.code.branch_hint", ".debug_info"] {
    let protected = input.with_custom_secs([
      @lib.CustomSec::new(@lib.Name::new(name), b"\x00"),
    ])
    @debug.assert_eq(
      @binary.encode_module(reorder_globals_run_module_pass(protected)),
      @binary.encode_module(protected),
    )
  }
}

///|
test "function packing experiment preserves import ABI and remaps every fixture root" {
  // This controlled experiment is not a public ReorderFunctions implementation.
  // The fixture has no offset metadata, raw names, function facts or annotations.
  let cold = Array::make(126, "(func)").join("\n")
  let input = pass_test_module_from_wat(
    "(module (import \"host\" \"fixed\" (func)) (func (param i32)) \{cold} (func nop) (func (call 128) (call 128) (ref.func 128) drop) (global funcref (ref.func 128)) (elem declare func 128) (start 128) (export \"hot\" (func 128)) (export \"entry\" (func 129)) (export \"fixed\" (func 0)))",
  ).with_name_sec(
    @lib.NameSec::new(
      func_names=Some(
        @lib.NameMap::new([@lib.NameAssoc::new(128U, @lib.Name::new("hot"))]),
      ),
    ),
  )
  ignore(@validate.validate_module(input).unwrap())
  let original_bytes = @binary.encode_module(input).unwrap()
  let remap = Array::makei(130, fn(index) { index.to_uint() })
  remap[1] = 128U
  remap[128] = 1U
  let rewritten = dfe_rewrite_module_func_idxs(input, remap)
  let funcs = rewritten.code_sec.unwrap().0.copy()
  let signatures = rewritten.func_sec.unwrap().0.copy()
  funcs[0] = rewritten.code_sec.unwrap().0[127]
  funcs[127] = rewritten.code_sec.unwrap().0[0]
  signatures[0] = rewritten.func_sec.unwrap().0[127]
  signatures[127] = rewritten.func_sec.unwrap().0[0]
  let names = input.name_sec.unwrap().func_names.unwrap()
  let name_remap : Map[UInt32, UInt32] = Map([])
  name_remap[128U] = 1U
  let names = dfe_rewrite_name_map_filtered(names, name_remap, false)
  let candidate = rewritten
    .with_code_sec(@lib.CodeSec::new(funcs))
    .with_func_sec(@lib.FuncSec::new(signatures))
    .with_name_sec(@lib.NameSec::new(func_names=Some(names)))
  ignore(@validate.validate_module(candidate).unwrap())
  @debug.assert_eq(candidate.import_sec, input.import_sec)
  @debug.assert_eq(
    candidate.func_sec.unwrap().0[0],
    input.func_sec.unwrap().0[127],
  )
  @debug.assert_eq(
    candidate.func_sec.unwrap().0[127],
    input.func_sec.unwrap().0[0],
  )
  @debug.assert_eq(
    candidate.code_sec.unwrap().0[0],
    input.code_sec.unwrap().0[127],
  )
  @debug.assert_eq(
    candidate.code_sec.unwrap().0[127],
    input.code_sec.unwrap().0[0],
  )
  @debug.assert_eq(
    candidate.start_sec,
    Some(@lib.StartSec::new(@lib.FuncIdx::new(1U))),
  )
  let @lib.Func(_, @lib.Expr(body)) = candidate.code_sec.unwrap().0[128]
  @debug.assert_eq(body, [
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
    @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
    @lib.Instruction::drop(),
  ])
  @debug.assert_eq(candidate.global_sec.unwrap().0[0].1.0, [
    @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
  ])
  @debug.assert_eq(
    candidate.elem_sec.unwrap().0[0].1,
    @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
  )
  let exports = candidate.export_sec.unwrap().0
  @debug.assert_eq(exports[0].1, @lib.ExternIdx::func(@lib.FuncIdx::new(1U)))
  @debug.assert_eq(exports[1], input.export_sec.unwrap().0[1])
  @debug.assert_eq(exports[2], input.export_sec.unwrap().0[2])
  @debug.assert_eq(candidate.name_sec.unwrap().func_names.unwrap().0[0].0, 1U)
  // Calls (2), body ref.func, initializer, element, start, export and name.
  @debug.assert_eq(index_packing_size(candidate), index_packing_size(input) - 8)
  @debug.assert_eq(@binary.encode_module(input).unwrap(), original_bytes)
}

///|
test "private singleton type packing experiment counts signed and unsigned widths" {
  // All groups are independent unshared function types; no public type escapes.
  // Recursive, subtype and descriptor graphs need a separate production owner.
  for hot in [64, 128] {
    let types = Array::make(129, "(type (func))").join("\n")
    let input = pass_test_module_from_wat(
      "(module \{types} (func (type \{hot}) (block (type \{hot})) (ref.null \{hot}) drop))",
    ).with_name_sec(
      @lib.NameSec::new(
        type_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(hot.to_uint(), @lib.Name::new("hot")),
          ]),
        ),
      ),
    )
    ignore(@validate.validate_module(input).unwrap())
    let remap : Map[UInt32, UInt32] = Map([])
    remap[0U] = hot.to_uint()
    remap[hot.to_uint()] = 0U
    let rewritten = dfe_rewrite_module_type_idxs(input, remap)
    let groups = rewritten.type_sec.unwrap().0.copy()
    groups[0] = rewritten.type_sec.unwrap().0[hot]
    groups[hot] = rewritten.type_sec.unwrap().0[0]
    let candidate = rewritten
      .with_type_sec(@lib.TypeSec::new(groups))
      .with_name_sec(dfe_rewrite_type_name_sec(input.name_sec.unwrap(), remap))
    ignore(@validate.validate_module(candidate).unwrap())
    @debug.assert_eq(candidate.func_sec.unwrap().0, [@lib.TypeIdx::new(0U)])
    let @lib.Func(_, @lib.Expr(body)) = candidate.code_sec.unwrap().0[0]
    @debug.assert_eq(
      body[0],
      @lib.Instruction::block(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
        @lib.Expr::new([]),
      ),
    )
    @debug.assert_eq(
      body[1],
      @lib.Instruction::ref_null(@lib.HeapType::new(@lib.TypeIdx::new(0U))),
    )
    @debug.assert_eq(candidate.name_sec.unwrap().type_names.unwrap().0[0].0, 0U)
    let saving = if hot == 64 { 2 } else { 4 }
    @debug.assert_eq(
      index_packing_size(candidate),
      index_packing_size(input) - saving,
    )
  }
}
