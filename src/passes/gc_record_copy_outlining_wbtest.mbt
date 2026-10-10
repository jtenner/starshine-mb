///|
fn gc_copy_test_module(
  fields : Int,
  arms : Int,
  rec_prefix? : Bool = false,
) -> @lib.Module {
  let source = StringBuilder::new()
  source.write_string("(module")
  if rec_prefix {
    source.write_string(" (rec (type (func)) (type (func (param i32))))")
  }
  source.write_string(" (type $r (struct")
  for _ in 0..<fields {
    source.write_string(" (field i32)")
  }
  source.write_string(
    ")) (import \"env\" \"observe\" (func $observe (param i32)))",
  )
  source.write_string(" (func (export \"make\") (result (ref $r))")
  for field in 0..<fields {
    source.write_string(" i32.const \{field + 100}")
  }
  source.write_string(" struct.new $r)")
  source.write_string(
    " (func (export \"update\") (param (ref null $r) i32) (result (ref null $r)) local.get 1 call $observe",
  )
  for selected in 0..<arms {
    source.write_string(
      " local.get 1 i32.const \{selected} i32.eq if (result (ref null $r))",
    )
    for field in 0..<fields {
      if field == selected {
        source.write_string(" i32.const \{selected + 41}")
      } else {
        source.write_string(" local.get 0 struct.get $r \{field}")
      }
    }
    source.write_string(" struct.new $r else")
  }
  source.write_string(" local.get 0")
  for _ in 0..<arms {
    source.write_string(" end")
  }
  source.write_string("))")
  pass_test_module_from_wat(source.to_string())
}

///|
test "GC record-copy outlining rejects unsupported record definitions" {
  let immutable = @lib.FieldType::new(
    @lib.StorageType::val_type(@lib.ValType::i32()),
    @lib.Mut::const_(),
  )
  let fields = Array::make(12, immutable)
  let comp = @lib.CompType::struct_(fields)
  assert_eq(gc_record_copy_type_fields(@lib.SubType::comp_type(comp)), Some(12))
  for
    unsupported in [
      @lib.SubType::new(false, [], comp),
      @lib.SubType::new(true, [@lib.TypeIdx::new(0U)], comp),
      @lib.SubType::comp_type(
        comp,
        metadata=@lib.TypeMetadata::new(shared=true),
      ),
      @lib.SubType::comp_type(
        comp,
        metadata=@lib.TypeMetadata::new(descriptor=Some(@lib.TypeIdx::new(1U))),
      ),
      @lib.SubType::comp_type(
        comp,
        metadata=@lib.TypeMetadata::new(describes=Some(@lib.TypeIdx::new(1U))),
      ),
      @lib.SubType::comp_type(@lib.CompType::struct_([immutable])),
      @lib.SubType::comp_type(
        @lib.CompType::struct_(Array::make(513, immutable)),
      ),
      @lib.SubType::comp_type(
        @lib.CompType::struct_(
          Array::make(
            12,
            @lib.FieldType::new(
              @lib.StorageType::val_type(@lib.ValType::i32()),
              @lib.Mut::var_(),
            ),
          ),
        ),
      ),
      @lib.SubType::comp_type(
        @lib.CompType::struct_(
          Array::make(
            12,
            @lib.FieldType::new(
              @lib.StorageType::pack_type(@lib.PackType::i8()),
              @lib.Mut::const_(),
            ),
          ),
        ),
      ),
    ] {
    assert_eq(gc_record_copy_type_fields(unsupported), None)
  }
}

///|
test "GC record-copy outlining rejects effects multiple sources and unordered fields" {
  let input = gc_copy_test_module(12, 12)
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[1]
  let arm = match body[5] {
    @lib.If(_, arm, _) => arm
    _ => abort("expected copy arm")
  }
  let fields : @hashmap.HashMap[UInt, Int] = @hashmap.new()
  fields.set(0U, 12)
  assert_true(gc_record_copy_match(arm, arm.length() - 1, fields) is Some(_))
  for
    (position, replacement) in [
      (0, @lib.Instruction::call(@lib.FuncIdx::new(0U))),
      (1, @lib.Instruction::local_get(@lib.LocalIdx::new(1U))),
      (
        2,
        @lib.Instruction::struct_get(@lib.TypeIdx::new(0U), @lib.U32::new(2U)),
      ),
      (
        2,
        @lib.Instruction::struct_get(@lib.TypeIdx::new(1U), @lib.U32::new(1U)),
      ),
      (
        2,
        @lib.Instruction::struct_get_s(@lib.TypeIdx::new(0U), @lib.U32::new(1U)),
      ),
      (2, @lib.Instruction::i32_const(7)),
    ] {
    let candidate = arm.copy()
    candidate[position] = replacement
    assert_true(
      gc_record_copy_match(candidate, candidate.length() - 1, fields) is None,
    )
  }
}

///|
test "GC record-copy outlining keeps exact references outside its supported slice" {
  let exact = @lib.ValType::ref_type(
    @lib.RefType::new(
      true,
      @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      exact=true,
    ),
  )
  assert_false(
    gc_record_copy_function_supported(
      Some(@lib.FuncType::new([exact], [])),
      @lib.Locals::empty(),
    ),
  )
  assert_false(
    gc_record_copy_function_supported(
      Some(@lib.FuncType::new([], [exact])),
      @lib.Locals::empty(),
    ),
  )
  assert_false(
    gc_record_copy_function_supported(
      Some(@lib.FuncType::new([], [])),
      @lib.Locals::single(1U, exact),
    ),
  )
}

///|
test "GC record-copy outlining rejects compressed local excess for the whole module" {
  let input = gc_copy_test_module(12, 12)
  let types = input.func_sec.unwrap().0.copy()
  let funcs = input.code_sec.unwrap().0.copy()
  types.push(types[0])
  funcs.push(
    @lib.Func::new(
      @lib.Locals::single(65537U, @lib.ValType::i32()),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
  )
  let over = input
    .with_func_sec(@lib.FuncSec::new(types))
    .with_code_sec(@lib.CodeSec::new(funcs))
  assert_true(physical_equal(gc_record_copy_outline_module(over), over))
  assert_true(
    gc_record_copy_function_bounded(
      Some(@lib.FuncType::new([], [])),
      @lib.Locals::single(65536U, @lib.ValType::i32()),
    ),
  )
  assert_false(
    gc_record_copy_function_bounded(
      Some(@lib.FuncType::new([], [])),
      @lib.Locals::single(0xffffffffU, @lib.ValType::i32()),
    ),
  )
}

///|
test "GC record-copy outlining appends after flattened recursive types and imports" {
  let input = gc_copy_test_module(12, 12, rec_prefix=true)
  let output = gc_record_copy_outline_module(input)
  @validate.validate_module(output).unwrap()
  let original_flat = msf_build_type_signature_cache(input).length()
  assert_eq(
    output.func_sec.unwrap().0.last(),
    Some(@lib.TypeIdx::new(original_flat.reinterpret_as_uint())),
  )
  assert_eq(
    output.code_sec.unwrap().0.length(),
    input.code_sec.unwrap().0.length() + 1,
  )
  assert_eq(output.import_sec, input.import_sec)
  assert_eq(output.export_sec, input.export_sec)
}

///|
test "GC record-copy outlining keeps undersampled modules unchanged" {
  for input in [gc_copy_test_module(8, 1), gc_copy_test_module(8, 7)] {
    assert_true(physical_equal(gc_record_copy_outline_module(input), input))
  }
}

///|
test "GC record-copy outlining bounds excluded functions and initializer controls" {
  let input = gc_copy_test_module(12, 12)
  let mut deep = [@lib.Instruction::nop()]
  for _ in 0..<129 {
    deep = [
      @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(deep)),
    ]
  }
  let fields : @hashmap.HashMap[UInt, Int] = @hashmap.new()
  let counts : @hashmap.HashMap[UInt, Int] = @hashmap.new()
  assert_false(
    gc_record_copy_scan(deep, fields, counts, [8000000, 0], 0, false),
  )
  let bad = input.with_global_sec(
    @lib.GlobalSec::new([
      @lib.Global::new(
        @lib.GlobalType::new(@lib.ValType::i32(), false),
        @lib.Expr::new(deep),
      ),
    ]),
  )
  assert_true(physical_equal(gc_record_copy_outline_module(bad), bad))
  assert_false(
    gc_record_copy_scan(
      [@lib.Instruction::nop()],
      fields,
      counts,
      [0, 0],
      0,
      false,
    ),
  )
}

///|
#skip("dedicated compressed declaration run threshold")
test "GC record-copy outlining rejects 65537 zero-count runs before snapshot conversion" {
  let signature = Some(@lib.FuncType::new([], []))
  let run = @lib.LocalRun::new(0U, @lib.ValType::i32())
  assert_true(
    gc_record_copy_function_bounded(
      signature,
      @lib.Locals::from_decl_runs_preserving_groups(Array::make(65536, run)),
    ),
  )
  assert_false(
    gc_record_copy_function_bounded(
      signature,
      @lib.Locals::from_decl_runs_preserving_groups(Array::make(65537, run)),
    ),
  )
}

///|
fn gc_copy_test_count(
  body : Array[@lib.Instruction],
  predicate : (@lib.Instruction) -> Bool,
) -> Int {
  let mut count = 0
  for instr in body {
    if predicate(instr) {
      count += 1
    }
    match instr {
      @lib.Block(_, @lib.Expr(child)) | @lib.Loop(_, @lib.Expr(child)) =>
        count += gc_copy_test_count(child, predicate)
      @lib.If(_, left, right) => {
        count += gc_copy_test_count(left, predicate)
        if right is Some(child) {
          count += gc_copy_test_count(child, predicate)
        }
      }
      _ => ()
    }
  }
  count
}

///|
test "GC record-copy outlining shares allocations without rewriting original indices" {
  let input = gc_copy_test_module(12, 12)
  let saved = @binary.encode_module(input).unwrap()
  let output = merge_similar_functions_run_module_pass(input)
  @validate.validate_module(output).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  assert_true(@binary.encode_module(output).unwrap().length() < saved.length())
  assert_eq(output.import_sec, input.import_sec)
  assert_eq(output.export_sec, input.export_sec)
  let funcs = output.code_sec.unwrap().0
  assert_eq(funcs.length(), 3)
  let @lib.Func(_, @lib.Expr(body)) = funcs[1]
  assert_eq(
    gc_copy_test_count(body, fn(instr) { instr is @lib.StructNew(_) }),
    0,
  )
  assert_eq(
    gc_copy_test_count(body, fn(instr) {
      instr == @lib.Instruction::call(@lib.FuncIdx::new(3U))
    }),
    12,
  )
  let @lib.Func(_, @lib.Expr(helper)) = funcs[2]
  assert_eq(
    gc_copy_test_count(helper, fn(instr) { instr is @lib.StructNew(_) }),
    1,
  )
  assert_eq(
    gc_copy_test_count(helper, fn(instr) { instr is @lib.Select(_) }),
    12,
  )
}

///|
test "GC record-copy outlining rolls back a whole-module validation failure" {
  let input = gc_copy_test_module(12, 12)
  // Deliberately invalid but resource-bounded IR: matching source operands
  // refer to a nonexistent local. Encoding succeeds; full validation rejects.
  let funcs = input.code_sec.unwrap().0.copy()
  let @lib.Func(locals, @lib.Expr(body)) = funcs[1]
  fn invalidate(body : Array[@lib.Instruction]) -> Array[@lib.Instruction] {
    body.map(fn(instr) {
      match instr {
        @lib.LocalGet(@lib.LocalIdx(0U)) =>
          @lib.Instruction::local_get(@lib.LocalIdx::new(99U))
        @lib.If(type_, arm, rest) =>
          @lib.Instruction::if_(type_, invalidate(arm), rest.map(invalidate))
        _ => instr
      }
    })
  }
  funcs[1] = @lib.Func::new(locals, @lib.Expr::new(invalidate(body)))
  let invalid = input.with_code_sec(@lib.CodeSec::new(funcs))
  assert_true(@validate.validate_module(invalid) is Err(_))
  assert_true(physical_equal(gc_record_copy_outline_module(invalid), invalid))
}

///|
#skip("dedicated artifact-depth admission regression")
test "GC record-copy outlining preserves unrelated artifact-depth bodies" {
  let input = gc_copy_test_module(12, 12)
  let mut deep = [@lib.Instruction::nop()]
  for _ in 0..<567 {
    deep = [
      @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(deep)),
    ]
  }
  let types = input.func_sec.unwrap().0.copy()
  let funcs = input.code_sec.unwrap().0.copy()
  types.push(@lib.TypeIdx::new(1U))
  let untouched = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(deep))
  funcs.push(untouched)
  let original = input
    .with_func_sec(@lib.FuncSec::new(types))
    .with_code_sec(@lib.CodeSec::new(funcs))
  @validate.validate_module(original).unwrap()
  let output = gc_record_copy_outline_module(original)
  assert_eq(output.code_sec.unwrap().0.length(), funcs.length() + 1)
  assert_true(physical_equal(output.code_sec.unwrap().0[2], untouched))
  @validate.validate_module(output).unwrap()
}

///|
#skip("dedicated validation ceiling and rollback regression")
test "GC record-copy outlining bounds deep validation separately from rewriting" {
  for depth in [1024, 1025] {
    let mut deep = [@lib.Instruction::nop()]
    for _ in 0..<depth {
      deep = [
        @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(deep)),
      ]
    }
    let budget = [8000000, 0]
    assert_eq(
      gc_record_copy_preflight(deep, budget),
      if depth == 1024 {
        Some(1024)
      } else {
        None
      },
    )
    let input = gc_copy_test_module(12, 12)
    let types = input.func_sec.unwrap().0.copy()
    let funcs = input.code_sec.unwrap().0.copy()
    types.push(@lib.TypeIdx::new(1U))
    let untouched = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(deep))
    funcs.push(untouched)
    let original = input
      .with_func_sec(@lib.FuncSec::new(types))
      .with_code_sec(@lib.CodeSec::new(funcs))
    let output = gc_record_copy_outline_module(original)
    if depth == 1024 {
      assert_eq(output.code_sec.unwrap().0.length(), funcs.length() + 1)
      assert_true(physical_equal(output.code_sec.unwrap().0[2], untouched))
      @validate.validate_module(output).unwrap()
    } else {
      assert_true(physical_equal(output, original))
    }
  }
}

///|
#skip("dedicated deep-invalid full candidate rollback")
test "GC record-copy outlining rolls back invalid deep untouched bodies" {
  for
    leaf in [
      @lib.Instruction::local_get(@lib.LocalIdx::new(99U)),
      @lib.Instruction::br(@lib.LabelIdx::new(9999U)),
      @lib.Instruction::i32_const(1),
    ] {
    let input = gc_copy_test_module(12, 12)
    let mut deep = [leaf]
    for _ in 0..<567 {
      deep = [
        @lib.Instruction::block(@lib.BlockType::void_(), @lib.Expr::new(deep)),
      ]
    }
    let types = input.func_sec.unwrap().0.copy()
    let funcs = input.code_sec.unwrap().0.copy()
    types.push(@lib.TypeIdx::new(1U))
    funcs.push(@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(deep)))
    let invalid = input
      .with_func_sec(@lib.FuncSec::new(types))
      .with_code_sec(@lib.CodeSec::new(funcs))
    assert_true(@validate.validate_module(invalid) is Err(_))
    assert_true(physical_equal(gc_record_copy_outline_module(invalid), invalid))
  }
}

///|
test "GC record-copy outlining charges unused type shapes before candidate work" {
  let input = gc_copy_test_module(12, 12)
  let types = input.type_sec.unwrap().0.copy()
  let field = @lib.FieldType::new(
    @lib.StorageType::val_type(@lib.ValType::i32()),
    @lib.Mut::const_(),
  )
  types.push(
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::struct_(Array::make(1500, field))),
    ),
  )
  let original = input.with_type_sec(@lib.TypeSec::new(types))
  @validate.validate_module(original).unwrap()
  assert_true(
    physical_equal(
      gc_record_copy_outline_module(original, analysis_budget=2000),
      original,
    ),
  )
  // The ordinary production budget still accepts this small valid record.
  assert_false(
    physical_equal(gc_record_copy_outline_module(original), original),
  )
}

///|
test "GC record-copy type shape budget counts function struct array group and supers" {
  let field = @lib.FieldType::new(
    @lib.StorageType::val_type(@lib.ValType::i32()),
    @lib.Mut::const_(),
  )
  let function = @lib.SubType::comp_type(
    @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
      @lib.ValType::i64(),
      @lib.ValType::i64(),
      @lib.ValType::i64(),
    ]),
  )
  let record = @lib.SubType::comp_type(
    @lib.CompType::struct_(Array::make(4, field)),
  )
  let array = @lib.SubType::comp_type(@lib.CompType::array(field))
  let inherited = @lib.SubType::new(
    false,
    [@lib.TypeIdx::new(0U), @lib.TypeIdx::new(1U)],
    @lib.CompType::struct_(Array::make(4, field)),
  )
  for
    (types, expected) in [
      ([@lib.RecType::new(function)], 7),
      ([@lib.RecType::new(record)], 6),
      ([@lib.RecType::new(array)], 3),
      (
        [
          @lib.RecType::new(
            @lib.SubType::comp_type(@lib.CompType::cont(@lib.TypeIdx::new(0U))),
          ),
        ],
        3,
      ),
      ([@lib.RecType::new(inherited)], 8),
      ([@lib.RecType::group([record, array])], 10),
    ] {
    let exact = [expected, 0]
    assert_true(gc_record_copy_types_bounded(types, exact))
    assert_eq(exact[0], 0)
    assert_false(gc_record_copy_types_bounded(types, [expected - 1, 0]))
    assert_false(gc_record_copy_types_bounded(types, [-1, 0]))
  }
  assert_true(gc_record_copy_types_bounded([], [0, 0]))
  let fields : @hashmap.HashMap[UInt, Int] = @hashmap.new()
  let counts : @hashmap.HashMap[UInt, Int] = @hashmap.new()
  let module_ = gc_copy_test_module(12, 12).with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::passive(),
        @lib.ElemKind::funcs([@lib.FuncIdx::new(1U), @lib.FuncIdx::new(1U)]),
      ),
    ]),
  )
  assert_false(
    gc_record_copy_initializers_bounded(module_, fields, counts, [1, 0]),
  )
  assert_true(
    gc_record_copy_initializers_bounded(module_, fields, counts, [2, 0]),
  )
}

///|
#skip("dedicated eight-million type structural-unit boundary")
test "GC record-copy type shapes admit eight million units and reject one beyond" {
  let common = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func(Array::make(120, @lib.ValType::i32()), []),
    ),
  )
  let types = Array::make(65536, common)
  types[65535] = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func(Array::make(4728, @lib.ValType::i32()), []),
    ),
  )
  let budget = [8000000, 0]
  assert_true(gc_record_copy_types_bounded(types, budget))
  assert_eq(budget[0], 0)
  types[65535] = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func(Array::make(4729, @lib.ValType::i32()), []),
    ),
  )
  assert_false(gc_record_copy_types_bounded(types, [8000000, 0]))
}
