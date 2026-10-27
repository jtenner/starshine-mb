///|
test "review optimize casts keeps function references outside the any hierarchy" {
  let module_ctx = @ir.hot_module_context_from_module(
    @lib.Module::new().with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    ),
  )
  let source = @lib.RefType::new(
    false,
    @lib.HeapType::new(@lib.TypeIdx::new(0U)),
  )
  let target = @lib.RefType::new(
    false,
    @lib.HeapType::abs(@lib.AbsHeapType::any()),
  )
  assert_false(oc_ref_always_matches(module_ctx, source, target))
  assert_true(oc_ref_never_matches(module_ctx, source, target))
  assert_true(
    oc_ref_always_matches(
      module_ctx,
      source,
      @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::func())),
    ),
  )
}

///|
test "review GTO shifts descriptor field names with inserted placeholders" {
  let input = pass_test_module_from_wat(
    "(module (rec (type $s (sub (descriptor $d) (struct))) (type $d (sub (describes $s) (struct (field (mut i32)) (field (mut i32)))))) (func (export \"run\") (result i32) (local $d (ref null $d)) (local.set $d (struct.new $d (i32.const 10) (i32.const 20))) (drop (extern.convert_any (struct.new_default_desc $s (struct.new $d (i32.const 1) (i32.const 2))))) (drop (struct.get $d 0 (local.get $d))) (struct.get $d 1 (local.get $d))))",
  ).with_name_sec(
    @lib.NameSec::new(
      field_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            1U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::new("first")),
              @lib.NameAssoc::new(1U, @lib.Name::new("second")),
            ]),
          ),
        ]),
      ),
    ),
  )
  let output = global_type_optimization_run_module_pass(input, true)
  let @lib.IndirectNameMap(entries) = output.name_sec.unwrap().field_names.unwrap()
  assert_eq(entries, [
    @lib.IndirectNameAssoc::new(
      1U,
      @lib.NameMap::new([
        @lib.NameAssoc::new(1U, @lib.Name::new("first")),
        @lib.NameAssoc::new(2U, @lib.Name::new("second")),
      ]),
    ),
  ])
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "review string gathering clears malformed raw names after rewriting globals" {
  let input = pass_test_module_from_wat(
    "(module (global i32 (i32.const 7)) (func (result stringref) (string.const \"hello\")))",
  ).with_raw_name_sec_payload(b"opaque-global-names")
  let output = string_gathering_run_module_pass(input)
  assert_eq(output.raw_name_sec_payload, None)
  assert_eq(output.global_sec.unwrap().0.length(), 2)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(body, [@lib.Instruction::global_get(@lib.GlobalIdx::new(0U))])
  assert_eq(input.raw_name_sec_payload, Some(b"opaque-global-names"))
  assert_eq(input.global_sec.unwrap().0.length(), 1)
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "review raw names survive string gathering when there are no strings" {
  let input = pass_test_module_from_wat("(module (global i32 (i32.const 7)))").with_raw_name_sec_payload(
    b"opaque-global-names",
  )
  let output = string_gathering_run_module_pass(input)
  assert_eq(output.raw_name_sec_payload, input.raw_name_sec_payload)
  assert_eq(output.global_sec, input.global_sec)
}

///|
test "review precompute cleanup clears malformed raw names after pruning types" {
  let input = precompute_unused_gc_type_parity_fixture().with_raw_name_sec_payload(
    b"opaque-type-names",
  )
  let before_types = input.type_sec.unwrap().0.length()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["precompute"]).unwrap()
  assert_eq(output.type_sec.unwrap().0.length(), 2)
  assert_eq(output.raw_name_sec_payload, None)
  assert_eq(input.raw_name_sec_payload, Some(b"opaque-type-names"))
  assert_eq(input.type_sec.unwrap().0.length(), before_types)
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "review precompute cleanup keeps malformed raw names when code is unchanged" {
  let input = precompute_unused_gc_type_parity_fixture().with_raw_name_sec_payload(
    b"opaque-type-names",
  )
  let output = precompute_cleanup_unused_gc_types(input, input)
  assert_eq(output.raw_name_sec_payload, input.raw_name_sec_payload)
  assert_eq(output.type_sec, input.type_sec)
}

///|
test "review precompute cleanup clears raw names and remaps structured type names" {
  let named = precompute_unused_gc_type_parity_fixture().with_name_sec(
    @lib.NameSec::new(
      type_names=Some(
        @lib.NameMap::new([@lib.NameAssoc::new(4U, @lib.Name::new("result"))]),
      ),
    ),
  )
  let input = @binary.decode_module(@binary.encode_module(named).unwrap()).unwrap()
  assert_true(input.raw_name_sec_payload is Some(_))
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["precompute"]).unwrap()
  assert_eq(output.raw_name_sec_payload, None)
  assert_eq(output.type_sec.unwrap().0.length(), 2)
  assert_eq(
    output.name_sec.unwrap().type_names,
    Some(@lib.NameMap::new([@lib.NameAssoc::new(1U, @lib.Name::new("result"))])),
  )
  let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
  assert_eq(
    decoded.name_sec.unwrap().type_names,
    output.name_sec.unwrap().type_names,
  )
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "review string gathering remaps decoded names and invalidates code facts" {
  let named = pass_test_module_from_wat(
    "(module (global i32 (i32.const 7)) (func (result stringref) (string.const \"hello\")))",
  ).with_name_sec(
    @lib.NameSec::new(
      global_names=Some(
        @lib.NameMap::new([@lib.NameAssoc::new(0U, @lib.Name::new("old"))]),
      ),
    ),
  )
  let named = named.with_compiler_fact_custom_section(
    @representation.CompilerFactCustomSection::new(
      @representation.OptimizationFactsSec::new(),
    ),
  )
  let input = @binary.decode_module(@binary.encode_module(named).unwrap()).unwrap()
  let output = string_gathering_run_module_pass(input)
  assert_eq(output.raw_name_sec_payload, None)
  assert_eq(output.compiler_fact_custom_section, None)
  assert_eq(output.global_sec.unwrap().0.length(), 2)
  assert_eq(
    output.name_sec.unwrap().global_names,
    Some(@lib.NameMap::new([@lib.NameAssoc::new(1U, @lib.Name::new("old"))])),
  )
  let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
  assert_eq(
    decoded.name_sec.unwrap().global_names,
    output.name_sec.unwrap().global_names,
  )
}

///|
test "review GSI equivalent type classes merge candidates and poison" {
  let env = review_gsi_equivalence_fixture(3)
  let candidates = [[@lib.GlobalIdx::new(3U)], [], [@lib.GlobalIdx::new(5U)]]
  let poisoned = [false, false, false]
  gsi_merge_equivalent_struct_type_facts(env, poisoned, candidates)
  for row in candidates {
    assert_eq(row, [@lib.GlobalIdx::new(3U), @lib.GlobalIdx::new(5U)])
  }
  poisoned[2] = true
  gsi_merge_equivalent_struct_type_facts(env, poisoned, candidates)
  assert_eq(poisoned, [true, true, true])
}

///|
fn review_precompute_context(mod_ : @lib.Module) -> HotPassContext {
  HotPassContext::new(
    precompute_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    module_ctx=Some(@ir.hot_module_context_from_module(mod_)),
  )
}

///|
fn review_known_i32_field(value : PrecomputeKnownHeapValue?) -> Int32? {
  match value {
    Some(
      KnownStructFields(
        @lib.TypeIdx(0U),
        [KnownEmit(@lib.I32Const(@lib.I32(value)))]
      )
    ) => Some(value)
    None => None
    _ => abort("expected a single known i32 struct field")
  }
}

///|
test "review immutable global cache preserves values depth bounds and context isolation" {
  let first = pass_test_module_from_wat(
    "(module (type $s (struct (field i32))) (global (ref $s) (struct.new $s (i32.const 7))))",
  )
  let second = pass_test_module_from_wat(
    "(module (type $s (struct (field i32))) (global (ref $s) (struct.new $s (i32.const 9))))",
  )
  let index = @lib.GlobalIdx::new(0U)
  let first_ctx = review_precompute_context(first)
  let second_ctx = review_precompute_context(second)
  for ctx in [first_ctx, second_ctx] {
    for depth in [0, 32, 33] {
      let expected = review_reference_precompute_known_heap_value_from_global(
        ctx.module_ctx.unwrap(),
        index,
        depth,
      )
      assert_eq(
        review_known_i32_field(
          precompute_known_heap_value_from_global_cached(ctx, index, depth),
        ),
        review_known_i32_field(expected),
      )
      assert_eq(
        review_known_i32_field(
          precompute_known_heap_value_from_global_cached(ctx, index, depth),
        ),
        review_known_i32_field(expected),
      )
    }
  }
  assert_eq(
    review_known_i32_field(
      precompute_known_heap_value_from_global_cached(first_ctx, index, 0),
    ),
    Some(7),
  )
  assert_eq(
    review_known_i32_field(
      precompute_known_heap_value_from_global_cached(second_ctx, index, 0),
    ),
    Some(9),
  )
}

///|
test "review raw precompute admission preserves nested folds and effects" {
  for
    source in [
      "(module (func (result i32) i32.const 1 i32.const 2 i32.add))", "(module (func block nop nop end nop))",
      "(module (func (param i32) (result i32) local.get 0 if (result i32) i32.const 7 else i32.const 9 end))",
      "(module (func (result i32) block (result i32) i32.const 7 br 0 end))", "(module (func $effect (result i32) i32.const 9) (func call $effect drop))",
      "(module (func (result i32) i32.const 1 if (result i32) i32.const 7 else i32.const 9 end))",
    ] {
    let input = pass_test_module_from_wat(source)
    let module_ctx = Some(@ir.hot_module_context_from_module(input))
    for func in input.code_sec.unwrap().0 {
      assert_eq(
        precompute_run_raw_func(func, module_ctx),
        review_reference_precompute_run_raw_func(func, module_ctx),
      )
    }
    assert_true(
      @validate.validate_module(
        run_hot_pipeline(input, HotPipelineOptions::new(), ["precompute"]).unwrap(),
      )
      is Ok(_),
    )
  }
}

///|
fn review_reorder_fixture() -> @lib.Module {
  let globals = Array::makei(130, fn(index) {
    @lib.Global::new(
      @lib.GlobalType::new(@lib.ValType::i32(), false),
      @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(index))]),
    )
  })
  let body : Array[@lib.Instruction] = []
  for _ in 0..<32 {
    body.push(@lib.Instruction::global_get(@lib.GlobalIdx::new(129U)))
    body.push(@lib.Instruction::drop())
  }
  pass_test_module_from_wat("(module (func))")
  .with_global_sec(@lib.GlobalSec::new(globals))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
    ]),
  )
}

///|
test "review reorder size-plan dedup keeps canonical bytes and input ownership" {
  let input = review_reorder_fixture()
  let before = @binary.encode_module(input).unwrap()
  let output = reorder_globals_run_module_pass(input)
  let reference = review_reference_reorder_globals_run_module_pass_with_threshold(
    input, true,
  )
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
  assert_true(@binary.encode_module(output).unwrap().length() < before.length())
  assert_eq(@binary.encode_module(input).unwrap(), before)
  assert_true(@validate.validate_module(output) is Ok(_))
}

///|
test "review string gathering decodes and remaps valid raw-only global names" {
  let input = pass_test_module_from_wat(
    "(module (global i32 (i32.const 7)) (func (result stringref) (string.const \"hello\")))",
  ).with_raw_name_sec_payload(b"\x07\x06\x01\x00\x03old")
  let output = string_gathering_run_module_pass(input)
  assert_eq(output.global_sec.unwrap().0.length(), 2)
  assert_eq(
    output.name_sec.unwrap().global_names,
    Some(@lib.NameMap::new([@lib.NameAssoc::new(1U, @lib.Name::new("old"))])),
  )
  assert_eq(output.raw_name_sec_payload, None)
}

///|
test "review precompute cleanup decodes and remaps valid raw-only type names" {
  let input = precompute_unused_gc_type_parity_fixture().with_raw_name_sec_payload(
    b"\x04\x09\x01\x04\x06result",
  )
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), ["precompute"]).unwrap()
  assert_eq(output.type_sec.unwrap().0.length(), 2)
  assert_eq(output.raw_name_sec_payload, None)
  assert_eq(
    output.name_sec.unwrap().type_names,
    Some(@lib.NameMap::new([@lib.NameAssoc::new(1U, @lib.Name::new("result"))])),
  )
  assert_eq(output.raw_name_sec_payload, None)
}

///|
test "review cached global facts preserve mutable struct writes across control" {
  let input = pass_test_module_from_wat(
    "(module (type $s (struct (field (mut i32)) (field i32))) (global $g (ref $s) (struct.new $s (i32.const 7) (i32.const 11))) (func (export \"run\") (param i32) (result i32) i32.const 0))",
  ).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::if_(
            @lib.BlockType::void_(),
            [
              @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
              @lib.Instruction::i32_const(@lib.I32(9)),
              @lib.Instruction::struct_set(@lib.TypeIdx::new(0U), @lib.U32(0U)),
            ],
            None,
          ),
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::struct_get(@lib.TypeIdx::new(0U), @lib.U32(0U)),
          @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
          @lib.Instruction::struct_get(@lib.TypeIdx::new(0U), @lib.U32(1U)),
          @lib.Instruction::i32_add(),
        ]),
      ),
    ]),
  )
  assert_true(@validate.validate_module(input) is Ok(_))
  let ctx = review_precompute_context(input)
  let value = precompute_known_heap_value_from_global_cached(
    ctx,
    @lib.GlobalIdx::new(0U),
    0,
  ).unwrap()
  // Mutable fields intentionally cannot be read as initializer constants.
  assert_true(
    precompute_known_heap_struct_get(
      ctx,
      value,
      @lib.TypeIdx::new(0U),
      0U,
      false,
      false,
    )
    is None,
  )
  assert_true(
    precompute_known_heap_struct_get(
      ctx,
      value,
      @lib.TypeIdx::new(0U),
      1U,
      false,
      false,
    )
    is Some(KnownEmit(@lib.I32Const(@lib.I32(11)))),
  )
  for pass_ in ["precompute", "precompute-propagate"] {
    let output = match
      run_hot_pipeline(input, HotPipelineOptions::new(), [pass_]) {
      Ok(output) => output
      Err(err) => fail(err)
    }
    assert_eq(
      ca_test_opcode_count(
        output,
        @lib.Instruction::struct_get(@lib.TypeIdx::new(0U), @lib.U32(0U)),
      ),
      1,
    )
    assert_eq(
      ca_test_opcode_count(
        output,
        @lib.Instruction::struct_set(@lib.TypeIdx::new(0U), @lib.U32(0U)),
      ),
      1,
    )
    assert_true(@validate.validate_module(output) is Ok(_))
  }
}

///|
test "review precompute cleanup compares floating point literal bits" {
  let input = pass_test_module_from_wat(
    "(module (func (result f64) f64.const 0))",
  )
  let replace = fn(value) {
    input.with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::f64_const(@lib.F64::new(value))]),
        ),
      ]),
    )
  }
  let nan = 0x7ff8000000000011L.reinterpret_as_double()
  assert_false(precompute_cleanup_code_changed(replace(nan), replace(nan)))
  assert_true(precompute_cleanup_code_changed(replace(0.0), replace(-0.0)))
  assert_true(
    precompute_cleanup_code_changed(
      replace(nan),
      replace(0x7ff8000000000012L.reinterpret_as_double()),
    ),
  )
}

///|
test "review descriptor placeholder has no removed field name" {
  let names = @lib.NameSec::new(
    field_names=Some(
      @lib.IndirectNameMap::new([
        @lib.IndirectNameAssoc::new(
          0U,
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::new("removed")),
            @lib.NameAssoc::new(1U, @lib.Name::new("kept")),
          ]),
        ),
      ]),
    ),
  )
  assert_eq(
    gto_rewrite_descriptor_field_names(names, [1]).field_names,
    Some(
      @lib.IndirectNameMap::new([
        @lib.IndirectNameAssoc::new(
          0U,
          @lib.NameMap::new([@lib.NameAssoc::new(1U, @lib.Name::new("kept"))]),
        ),
      ]),
    ),
  )
}

///|
test "review GSI groups equivalent referenced types and keeps candidate rows separate" {
  let input = pass_test_module_from_wat(
    "(module (type $a (struct)) (type $b (struct)) (type $c (struct (field (ref $a)))) (type $d (struct (field (ref $b)))))",
  )
  let env = @validate.Env::new().with_module(input)
  let candidates = [
    [],
    [],
    [@lib.GlobalIdx::new(0U)],
    [@lib.GlobalIdx::new(1U)],
  ]
  let poisoned = [false, false, false, false]
  gsi_merge_equivalent_struct_type_facts(env, poisoned, candidates)
  assert_eq(candidates[2], [@lib.GlobalIdx::new(0U), @lib.GlobalIdx::new(1U)])
  assert_eq(candidates[3], candidates[2])
  candidates[2].clear()
  assert_eq(candidates[3], [@lib.GlobalIdx::new(0U), @lib.GlobalIdx::new(1U)])
}

///|
fn review_precompute_gate_expected(body : Array[@lib.Instruction]) -> Int32 {
  if precompute_raw_instrs_have_legacy_try(body) {
    return 1
  }
  let mut facts = 0
  if precompute_raw_instrs_have_stack_switching(body) {
    facts = facts | 2
  }
  if precompute_raw_instrs_have_atomic_fence(body) {
    facts = facts | 4
  }
  if precompute_raw_instrs_have_global_get(body) {
    facts = facts | 8
  }
  if precompute_raw_instrs_have_memory_grow(body) {
    facts = facts | 16
  }
  if precompute_raw_instrs_have_local_traffic(body) {
    facts = facts | 32
  }
  if precompute_raw_instrs_have_unreachable_suffix(body) {
    facts = facts | 64
  }
  facts
}

///|
test "review precompute original-body feature scan preserves dispatch results" {
  let fixtures : Array[@lib.Module] = []
  for
    wat in [
      "(module (func (param i32) (result i32) local.get 0))", "(module (global i32 (i32.const 1)) (func (result i32) global.get 0))",
      "(module (memory 1) (func (result i32) i32.const 0 memory.grow))", "(module (memory 1 1 shared) (func atomic.fence))",
      "(module (func (result i32) block (result i32) unreachable i32.const 1 end))",
      "(module (func (param i32) (result i32) local.get 0 if (result i32) i32.const 1 else i32.const 2 end))",
      "(module (func block try_table (catch_all 0) nop end end))",
    ] {
    match @wast.wast_to_binary_module(wat) {
      Ok(input) => fixtures.push(input)
      Err(err) => fail("invalid raw precompute WAT fixture: \{err}")
    }
  }
  let legacy = @lib.Instruction::try_(
    @lib.BlockType::void_(),
    @lib.Expr::new([@lib.Instruction::nop()]),
    [@lib.LegacyCatch::all(@lib.Expr::new([@lib.Instruction::nop()]))],
  )
  fixtures.push(
    pass_test_module_from_wat("(module (func))").with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([legacy])),
      ]),
    ),
  )
  for input in fixtures {
    match @validate.validate_module(input) {
      Ok(_) => ()
      Err(err) => fail("invalid raw precompute input fixture: \{err}")
    }
    let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    assert_eq(
      precompute_raw_gate_features(body),
      review_precompute_gate_expected(body),
    )
    for
      descriptor in [precompute_descriptor(), precompute_propagate_descriptor()] {
      let options = HotPipelineOptions::new()
      let before = review_reference_raw_precompute_dispatch(
        input,
        @lib.FuncIdx::new(0U),
        HotPipelineModuleState::new(),
        descriptor,
        options,
      )
      let after = run_hot_pipeline_raw_precompute(
        input,
        @lib.FuncIdx::new(0U),
        HotPipelineModuleState::new(),
        descriptor,
        options,
      )
      match (before, after) {
        (None, None) => ()
        (Some(before), Some(after)) => {
          assert_eq(after.reason, before.reason)
          assert_eq(after.unchanged_original, before.unchanged_original)
          assert_eq(after.trace_skip_raw, before.trace_skip_raw)
          let @lib.Func(after_locals, @lib.Expr(after_body)) = after.func
          let @lib.Func(before_locals, @lib.Expr(before_body)) = before.func
          assert_true(
            pass_const_instruction_vectors_bits_equal(after_body, before_body),
          )
          assert_eq(after_locals, before_locals)
          assert_true(
            @validate.validate_module(
              input.with_code_sec(@lib.CodeSec::new([after.func])),
            )
            is Ok(_),
          )
        }
        _ => abort("precompute dispatch decision changed")
      }
    }
  }
}

///|
fn review_gsi_active_reference_fixture(
  count : Int32,
  variants~ : Int32 = 512,
  flags~ : Bool = false,
) -> @lib.Module {
  let types : Array[@lib.RecType] = []
  // Nine scalar fields give512distinct leaf shapes with bounded fixture size.
  for slot in 0..<count {
    let fields : Array[@lib.FieldType] = []
    for bit in 0..<9 {
      fields.push(
        @lib.FieldType::new(
          @lib.StorageType::val_type(
            if ((slot % variants) & (1 << bit)) == 0 {
              @lib.ValType::i32()
            } else {
              @lib.ValType::i64()
            },
          ),
          @lib.Mut::const_(),
        ),
      )
    }
    types.push(
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::struct_(fields),
          metadata=@lib.TypeMetadata::new(shared=flags && slot % 4 >= 2),
        ),
      ),
    )
  }
  let globals : Array[@lib.Global] = []
  for slot in 0..<count {
    types.push(
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::struct_([
            @lib.FieldType::new(
              @lib.StorageType::val_type(
                @lib.ValType::ref_type(
                  @lib.RefType::new(
                    true,
                    @lib.HeapType::new(@lib.TypeIdx::new(slot.to_uint())),
                    exact=flags && slot % 2 == 1,
                  ),
                ),
              ),
              @lib.Mut::const_(),
            ),
          ]),
        ),
      ),
    )
    let index = @lib.TypeIdx::new((count + slot).to_uint())
    globals.push(
      @lib.Global::new(
        @lib.GlobalType::new(
          @lib.ValType::ref_type(
            @lib.RefType::new(false, @lib.HeapType::new(index)),
          ),
          false,
        ),
        @lib.Expr::new([@lib.Instruction::struct_new_default(index)]),
      ),
    )
  }
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new(types))
  .with_global_sec(@lib.GlobalSec::new(globals))
}

///|
fn review_gsi_active_reference_candidates(
  count : Int32,
) -> Array[Array[@lib.GlobalIdx]] {
  Array::makei(count * 2, fn(slot) {
    if slot < count {
      []
    } else {
      [@lib.GlobalIdx::new((slot - count).to_uint())]
    }
  })
}

///|
test "review GSI distinct active reference types match the original fact merge" {
  for count in [8, 16] {
    let input = review_gsi_active_reference_fixture(count)
    assert_true(@validate.validate_module(input) is Ok(_))
    let env = @validate.Env::new().with_module(input)
    let before = review_gsi_active_reference_candidates(count)
    let after = before.map(fn(values) { values.copy() })
    let before_poisoned = Array::make(count * 2, false)
    before_poisoned[count] = true
    let after_poisoned = before_poisoned.copy()
    review_reference_gsi_merge_equivalent_struct_type_facts(
      env, before_poisoned, before,
    )
    gsi_merge_equivalent_struct_type_facts(env, after_poisoned, after)
    assert_eq(after_poisoned, before_poisoned)
    assert_eq(after, before)
    assert_eq(after, review_gsi_active_reference_candidates(count))
  }
}

///|
fn review_gsi_assert_reference_class_merge(
  input : @lib.Module,
  count : Int32,
) -> Unit raise {
  assert_true(@validate.validate_module(input) is Ok(_))
  let env = @validate.Env::new().with_module(input)
  let before = review_gsi_active_reference_candidates(count)
  let after = before.map(fn(values) { values.copy() })
  let coarse = before.map(fn(values) { values.copy() })
  let before_poisoned = Array::make(count * 2, false)
  before_poisoned[count] = true
  let after_poisoned = before_poisoned.copy()
  let coarse_poisoned = before_poisoned.copy()
  review_reference_gsi_merge_equivalent_struct_type_facts(
    env, before_poisoned, before,
  )
  review_coarse_gsi_merge_equivalent_struct_type_facts(
    env, coarse_poisoned, coarse,
  )
  gsi_merge_equivalent_struct_type_facts(env, after_poisoned, after)
  assert_eq(after_poisoned, before_poisoned)
  assert_eq(after, coarse)
  assert_eq(after_poisoned, coarse_poisoned)
  assert_true(after[count].length() > 1)
  for slot in 0..<after.length() {
    let expected = before[slot].copy()
    let actual = after[slot].copy()
    gsi_sort_candidate_globals(expected)
    gsi_sort_candidate_globals(actual)
    assert_eq(actual, expected)
  }
  // This is the immediate production consumer of the merged fact rows.
  // It sorts candidates and removes poisoned candidates before any rewrite.
  gsi_propagate_closed_world_subtype_facts(env, before_poisoned, before)
  gsi_propagate_closed_world_subtype_facts(env, after_poisoned, after)
  assert_eq(after_poisoned, before_poisoned)
  assert_eq(after, before)
}

///|
test "review GSI dense reference classes preserve exact shared and recursive equivalence" {
  review_gsi_assert_reference_class_merge(
    review_gsi_active_reference_fixture(32, variants=4, flags=true),
    32,
  )
  let input = review_gsi_active_reference_fixture(16)
  let @lib.TypeSec(types) = input.type_sec.unwrap()
  let recursive = types.copy()
  for slot in 0..<16 {
    recursive[slot] = @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::struct_([
          @lib.FieldType::new(
            @lib.StorageType::val_type(
              @lib.ValType::ref_type(
                @lib.RefType::new(
                  true,
                  @lib.HeapType::new(@lib.TypeIdx::new(slot.to_uint())),
                ),
              ),
            ),
            @lib.Mut::const_(),
          ),
        ]),
      ),
    )
  }
  review_gsi_assert_reference_class_merge(
    input.with_type_sec(@lib.TypeSec::new(recursive)),
    16,
  )
  let mixed = recursive.copy()
  mixed[0] = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::val_type(
            @lib.ValType::ref_type(
              @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::rec(0U))),
            ),
          ),
          @lib.Mut::const_(),
        ),
      ]),
    ),
  )
  review_gsi_assert_reference_class_merge(
    input.with_type_sec(@lib.TypeSec::new(mixed)),
    16,
  )
}
