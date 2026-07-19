///|
fn heap2local_pair_fields(field_count : Int) -> Array[@lib.FieldType] {
  let fields : Array[@lib.FieldType] = []
  for _ in 0..<field_count {
    fields.push(
      @lib.FieldType::new(
        @lib.StorageType::val_type(@lib.ValType::i32()),
        @lib.Mut::var_(),
      ),
    )
  }
  fields
}

///|
fn heap2local_module_with_heap_type(
  heap_rec : @lib.RecType,
  result_types : Array[@lib.ValType],
  local_types : Array[@lib.ValType],
  body : Array[@lib.Instruction],
) -> @lib.Module {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], result_types)),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([heap_rec, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::from_types(local_types), @lib.Expr::new(body)),
    ]),
  )
}

///|
fn heap2local_module_with_locals(
  result_types : Array[@lib.ValType],
  local_types : Array[@lib.ValType],
  body : Array[@lib.Instruction],
) -> @lib.Module {
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::struct_(heap2local_pair_fields(2))),
  )
  heap2local_module_with_heap_type(struct_type, result_types, local_types, body)
}

///|
fn heap2local_i32_array_type() -> @lib.RecType {
  @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
}

///|
fn heap2local_run_module(mod_ : @lib.Module) -> @lib.Module {
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) => abort("unexpected invalid heap2local fixture: \{err}")
  }
  match run_hot_pipeline(mod_, HotPipelineOptions::new(), ["heap2local"]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected heap2local pipeline success, got \{err}")
  }
}

///|
fn heap2local_pretty_text(text : String) -> String {
  let optimized = match pass_test_run_pipeline(text, ["heap2local"]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected heap2local text fixture success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => optimized.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => abort("expected heap2local text output to validate, got \{err}")
  }
}

///|
test "heap2local rewrites a non-escaping struct local into scalar locals" {
  let pair = @lib.TypeIdx::new(0U)
  let owner_local = @lib.LocalIdx::new(0U)
  let optimized = heap2local_run_module(
    heap2local_module_with_locals(
      [@lib.ValType::i32()],
      [@lib.ValType::ref_null(@lib.HeapType::new(pair))],
      [
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::i32_const(@lib.I32(20)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(owner_local),
        @lib.Instruction::local_get(owner_local),
        @lib.Instruction::i32_const(@lib.I32(30)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(owner_local),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
    ),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected heap2local output to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.get"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
}

///|
test "heap2local leaves escaping struct locals unchanged" {
  let pair = @lib.TypeIdx::new(0U)
  let owner_local = @lib.LocalIdx::new(0U)
  let optimized = heap2local_run_module(
    heap2local_module_with_locals(
      [@lib.ValType::ref_null(@lib.HeapType::new(pair))],
      [@lib.ValType::ref_null(@lib.HeapType::new(pair))],
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::i32_const(@lib.I32(8)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(owner_local),
        @lib.Instruction::local_get(owner_local),
      ],
    ),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected heap2local escape fixture to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
}

///|
test "heap2local rewrites exclusive local copy chains into scalar locals" {
  let pair = @lib.TypeIdx::new(0U)
  let owner_local = @lib.LocalIdx::new(0U)
  let copy_local = @lib.LocalIdx::new(1U)
  let optimized = heap2local_run_module(
    heap2local_module_with_locals(
      [@lib.ValType::i32()],
      [
        @lib.ValType::ref_null(@lib.HeapType::new(pair)),
        @lib.ValType::ref_null(@lib.HeapType::new(pair)),
      ],
      [
        @lib.Instruction::i32_const(@lib.I32(11)),
        @lib.Instruction::i32_const(@lib.I32(22)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(owner_local),
        @lib.Instruction::local_get(owner_local),
        @lib.Instruction::local_set(copy_local),
        @lib.Instruction::local_get(copy_local),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
    ),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected heap2local local-copy output to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.get"), msg=pretty)
}

///|
test "heap2local rewrites direct tee owners into scalar locals" {
  let pretty = heap2local_pretty_text(
    (
      #| (module
      #|   (type $pair (sub (struct (field (mut i32)) (field (mut i32)))))
      #|   (func (result i32)
      #|     (local $ref (ref null $pair))
      #|     (struct.get $pair 0
      #|       (local.tee $ref
      #|         (struct.new_default $pair)))))
      #|
    ),
  )
  assert_false(pretty.contains("struct.new_default"), msg=pretty)
  assert_false(pretty.contains("struct.get"), msg=pretty)
  assert_false(pretty.contains("local.tee"), msg=pretty)
}

///|
test "heap2local rewrites simple block result flow into scalar locals" {
  let pretty = heap2local_pretty_text(
    (
      #| (module
      #|   (type $pair (sub (struct (field (mut i32)) (field (mut i32)))))
      #|   (func (result i32)
      #|     (local $ref (ref null $pair))
      #|     (local.set $ref
      #|       (struct.new_default $pair))
      #|     (struct.get $pair 1
      #|       (block (result (ref null $pair))
      #|         (drop (ref.null $pair))
      #|         (local.get $ref)))))
      #|
    ),
  )
  assert_false(pretty.contains("struct.new_default"), msg=pretty)
  assert_false(pretty.contains("struct.get"), msg=pretty)
}

///|
test "heap2local removes ref.as_non_null around optimized struct traffic" {
  let pretty = heap2local_pretty_text(
    (
      #| (module
      #|   (type $pair (sub (struct (field (mut i32)) (field (mut i32)))))
      #|   (func (result i32)
      #|     (local $ref (ref null $pair))
      #|     (local.set $ref
      #|       (struct.new_default $pair))
      #|     (struct.get $pair 0
      #|       (ref.as_non_null
      #|         (local.get $ref)))))
      #|
    ),
  )
  assert_false(pretty.contains("struct.new_default"), msg=pretty)
  assert_false(pretty.contains("struct.get"), msg=pretty)
  assert_false(pretty.contains("ref.as_non_null"), msg=pretty)
}

///|
test "heap2local removes successful ref.cast around optimized struct traffic" {
  let box = @lib.TypeIdx::new(0U)
  let temp = @lib.LocalIdx::new(0U)
  let optimized = heap2local_run_module(
    heap2local_module_with_locals(
      [@lib.ValType::i32()],
      [@lib.ValType::anyref()],
      [
        @lib.Instruction::i32_const(@lib.I32(11)),
        @lib.Instruction::i32_const(@lib.I32(22)),
        @lib.Instruction::struct_new(box),
        @lib.Instruction::local_tee(temp),
        @lib.Instruction::ref_cast(false, @lib.HeapType::new(box)),
        @lib.Instruction::struct_get(box, @lib.U32(0U)),
      ],
    ),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected heap2local ref.cast output to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.get"), msg=pretty)
  assert_false(pretty.contains("ref.cast"), msg=pretty)
}

///|
test "heap2local folds ref.eq against a fresh struct allocation to zero" {
  let pretty = heap2local_pretty_text(
    (
      #| (module
      #|   (type $box (sub (struct (field (mut i32)) (field (mut i32)))))
      #|   (func (result i32)
      #|     (ref.eq
      #|       (struct.new $box
      #|         (i32.const 0)
      #|         (i32.const 1))
      #|       (ref.null eq))))
      #|
    ),
  )
  assert_false(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("ref.eq"), msg=pretty)
  assert_true(pretty.contains("I32(0)"), msg=pretty)
}

///|
test "heap2local removes ref.get_desc around a fresh descriptor-bearing allocation" {
  let pretty = heap2local_pretty_text(
    (
      #| (module
      #|   (rec
      #|     (type $node
      #|       (descriptor $node_desc)
      #|       (struct))
      #|     (type $node_desc
      #|       (describes $node)
      #|       (struct)))
      #|   (func
      #|     (drop
      #|       (ref.get_desc $node
      #|         (struct.new_default_desc $node
      #|           (struct.new $node_desc))))))
      #|
    ),
  )
  assert_false(pretty.contains("struct.new_default_desc"), msg=pretty)
  assert_false(pretty.contains("ref.get_desc"), msg=pretty)
}

///|
test "heap2local lowers constant-size array.new_default through array.get" {
  let array = @lib.TypeIdx::new(0U)
  let ref_local = @lib.LocalIdx::new(0U)
  let optimized = heap2local_run_module(
    heap2local_module_with_heap_type(
      heap2local_i32_array_type(),
      [@lib.ValType::i32()],
      [@lib.ValType::ref_null(@lib.HeapType::new(array))],
      [
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::array_new_default(array),
        @lib.Instruction::local_set(ref_local),
        @lib.Instruction::local_get(ref_local),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::array_get(array),
      ],
    ),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected heap2local array.new_default output to validate, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("array.new_default"), msg=pretty)
  assert_false(pretty.contains("array.get"), msg=pretty)
}

///|
test "heap2local lowers constant-size array.new through array.get" {
  let array = @lib.TypeIdx::new(0U)
  let ref_local = @lib.LocalIdx::new(0U)
  let optimized = heap2local_run_module(
    heap2local_module_with_heap_type(
      heap2local_i32_array_type(),
      [@lib.ValType::i32()],
      [@lib.ValType::ref_null(@lib.HeapType::new(array))],
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::i32_const(@lib.I32(3)),
        @lib.Instruction::array_new(array),
        @lib.Instruction::local_set(ref_local),
        @lib.Instruction::local_get(ref_local),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::array_get(array),
      ],
    ),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected heap2local array.new output to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("array.new"), msg=pretty)
  assert_false(pretty.contains("array.get"), msg=pretty)
}

///|
test "heap2local lowers array.new_fixed with constant index set and get" {
  let array = @lib.TypeIdx::new(0U)
  let ref_local = @lib.LocalIdx::new(0U)
  let optimized = heap2local_run_module(
    heap2local_module_with_heap_type(
      heap2local_i32_array_type(),
      [@lib.ValType::i32()],
      [@lib.ValType::ref_null(@lib.HeapType::new(array))],
      [
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::i32_const(@lib.I32(5)),
        @lib.Instruction::array_new_fixed(array, @lib.U32(2U)),
        @lib.Instruction::local_set(ref_local),
        @lib.Instruction::local_get(ref_local),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::array_set(array),
        @lib.Instruction::local_get(ref_local),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::array_get(array),
      ],
    ),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected heap2local array.new_fixed output to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("array.new_fixed"), msg=pretty)
  assert_false(pretty.contains("array.set"), msg=pretty)
  assert_false(pretty.contains("array.get"), msg=pretty)
}

///|
test "heap2local lowers repeated same-owner fresh array allocations" {
  let array = @lib.TypeIdx::new(0U)
  let ref_local = @lib.LocalIdx::new(0U)
  let optimized = heap2local_run_module(
    heap2local_module_with_heap_type(
      heap2local_i32_array_type(),
      [],
      [@lib.ValType::ref_null(@lib.HeapType::new(array))],
      [
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::array_new_default(array),
        @lib.Instruction::local_set(ref_local),
        @lib.Instruction::local_get(ref_local),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::array_get(array),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::i32_const(@lib.I32(5)),
        @lib.Instruction::array_new_fixed(array, @lib.U32(2U)),
        @lib.Instruction::local_set(ref_local),
        @lib.Instruction::local_get(ref_local),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::array_set(array),
        @lib.Instruction::local_get(ref_local),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::array_get(array),
        @lib.Instruction::drop(),
      ],
    ),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected heap2local repeated array allocation output to validate, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("array.new_default"), msg=pretty)
  assert_false(pretty.contains("array.new_fixed"), msg=pretty)
  assert_false(pretty.contains("array.set"), msg=pretty)
  assert_false(pretty.contains("array.get"), msg=pretty)
}

///|
test "heap2local folds a direct fresh default struct field read" {
  let pair = @lib.TypeIdx::new(0U)
  let optimized = heap2local_run_module(
    heap2local_module_with_locals([@lib.ValType::i32()], [], [
      @lib.Instruction::struct_new_default(pair),
      @lib.Instruction::struct_get(pair, @lib.U32(0U)),
    ]),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("struct.new_default"), msg=pretty)
  assert_false(pretty.contains("struct.get"), msg=pretty)
  assert_true(pretty.contains("I32(0)"), msg=pretty)
}

///|
test "heap2local folds a direct fresh fixed-array field read" {
  let array = @lib.TypeIdx::new(0U)
  let optimized = heap2local_run_module(
    heap2local_module_with_heap_type(
      heap2local_i32_array_type(),
      [@lib.ValType::i32()],
      [],
      [
        @lib.Instruction::i32_const(@lib.I32(42)),
        @lib.Instruction::array_new_fixed(array, @lib.U32(1U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::array_get(array),
      ],
    ),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("array.new_fixed"), msg=pretty)
  assert_false(pretty.contains("array.get"), msg=pretty)
  assert_true(pretty.contains("I32(42)"), msg=pretty)
}

///|
test "heap2local folds a direct fresh fill-array field read" {
  let array = @lib.TypeIdx::new(0U)
  let optimized = heap2local_run_module(
    heap2local_module_with_heap_type(
      heap2local_i32_array_type(),
      [@lib.ValType::i32()],
      [],
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::i32_const(@lib.I32(3)),
        @lib.Instruction::array_new(array),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::array_get(array),
      ],
    ),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("array.new"), msg=pretty)
  assert_false(pretty.contains("array.get"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "heap2local folds direct packed fresh reads with signed extension" {
  let packed_struct = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::pack_type(@lib.PackType::i8()),
          @lib.Mut::var_(),
        ),
      ]),
    ),
  )
  let packed_array = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::pack_type(@lib.PackType::i8()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let optimized = heap2local_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([packed_struct, packed_array, func_type, func_type]),
    )
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(2U), @lib.TypeIdx::new(3U)]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(255)),
            @lib.Instruction::struct_new(@lib.TypeIdx::new(0U)),
            @lib.Instruction::struct_get_s(@lib.TypeIdx::new(0U), @lib.U32(0U)),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(255)),
            @lib.Instruction::array_new_fixed(
              @lib.TypeIdx::new(1U),
              @lib.U32(1U),
            ),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::array_get_s(@lib.TypeIdx::new(1U)),
          ]),
        ),
      ]),
    ),
  )
  for func_idx in [0, 1] {
    let pretty = optimized.pretty_print_func(
      @lib.FuncIdx::new(func_idx.reinterpret_as_uint()),
    )
    assert_false(pretty.contains("struct."), msg=pretty)
    assert_false(pretty.contains("array."), msg=pretty)
    assert_true(pretty.contains("I32(-1)"), msg=pretty)
  }
}

///|
test "heap2local preserves direct fixed-array out-of-bounds trapping" {
  let array = @lib.TypeIdx::new(0U)
  let optimized = heap2local_run_module(
    heap2local_module_with_heap_type(
      heap2local_i32_array_type(),
      [@lib.ValType::i32()],
      [],
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::array_new_fixed(array, @lib.U32(1U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::array_get(array),
      ],
    ),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("array.new_fixed"), msg=pretty)
  assert_false(pretty.contains("array.get"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "heap2local folds fresh struct ref.test to a constant" {
  let pair = @lib.TypeIdx::new(0U)
  let optimized = heap2local_run_module(
    heap2local_module_with_locals([@lib.ValType::i32()], [], [
      @lib.Instruction::struct_new_default(pair),
      @lib.Instruction::ref_test(false, @lib.HeapType::new(pair)),
    ]),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected heap2local struct ref.test output to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("struct.new_default"), msg=pretty)
  assert_false(pretty.contains("ref.test"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
}

///|
test "heap2local folds array ref.test to a constant" {
  let array = @lib.TypeIdx::new(0U)
  let optimized = heap2local_run_module(
    heap2local_module_with_heap_type(
      heap2local_i32_array_type(),
      [@lib.ValType::i32()],
      [],
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::array_new_default(array),
        @lib.Instruction::ref_test(false, @lib.HeapType::new(array)),
      ],
    ),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected heap2local array ref.test output to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("array.new_default"), msg=pretty)
  assert_false(pretty.contains("ref.test"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
}

///|
test "heap2local scalarizes repeated same-owner fresh struct allocations" {
  let pair = @lib.TypeIdx::new(0U)
  let owner_local = @lib.LocalIdx::new(0U)
  let optimized = heap2local_run_module(
    heap2local_module_with_locals(
      [],
      [@lib.ValType::ref_null(@lib.HeapType::new(pair))],
      [
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::i32_const(@lib.I32(20)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(owner_local),
        @lib.Instruction::local_get(owner_local),
        @lib.Instruction::i32_const(@lib.I32(30)),
        @lib.Instruction::struct_set(pair, @lib.U32(0U)),
        @lib.Instruction::local_get(owner_local),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
        @lib.Instruction::drop(),
        @lib.Instruction::struct_new_default(pair),
        @lib.Instruction::local_set(owner_local),
        @lib.Instruction::local_get(owner_local),
        @lib.Instruction::local_set(owner_local),
        @lib.Instruction::local_get(owner_local),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
        @lib.Instruction::drop(),
      ],
    ),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.get"), msg=pretty)
  assert_false(pretty.contains("struct.set"), msg=pretty)
}

///|
test "heap2local scalarizes an exclusive struct stored in a nullable GC supertype local" {
  let pair = @lib.TypeIdx::new(0U)
  let optimized = heap2local_run_module(
    heap2local_module_with_locals([], [@lib.ValType::anyref()], [
      @lib.Instruction::struct_new_default(pair),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("struct.new_default"), msg=pretty)
  assert_false(pretty.contains("local.get"), msg=pretty)
}

///|
test "heap2local v131 scalarizes sequential array and struct candidates with fresh analysis" {
  let pair = @lib.TypeIdx::new(0U)
  let array = @lib.TypeIdx::new(1U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let optimized = heap2local_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::struct_(heap2local_pair_fields(2)),
          ),
        ),
        heap2local_i32_array_type(),
        func_type,
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([
            @lib.ValType::ref_null(@lib.HeapType::new(array)),
            @lib.ValType::ref_null(@lib.HeapType::new(pair)),
          ]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_new_default(array),
            @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::array_set(array),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::array_get(array),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(10)),
            @lib.Instruction::i32_const(@lib.I32(20)),
            @lib.Instruction::struct_new(pair),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::struct_get(pair, @lib.U32(0U)),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    ),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("array.new_default"), msg=pretty)
  assert_false(pretty.contains("array.set"), msg=pretty)
  assert_false(pretty.contains("array.get"), msg=pretty)
  assert_false(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("struct.get"), msg=pretty)
}

///|
test "heap2local v131 scalarizes sequential branch-target struct candidates" {
  let pair = @lib.TypeIdx::new(0U)
  let pair_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(pair)),
  )
  let optimized = heap2local_run_module(
    heap2local_module_with_locals(
      [],
      [
        @lib.ValType::ref_null(@lib.HeapType::new(pair)),
        @lib.ValType::ref_null(@lib.HeapType::new(pair)),
      ],
      [
        @lib.Instruction::block(
          @lib.BlockType::val_type(pair_ref),
          @lib.Expr::new([
            @lib.Instruction::struct_new_default(pair),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::struct_get(pair, @lib.U32(0U)),
        @lib.Instruction::drop(),
        @lib.Instruction::block(
          @lib.BlockType::val_type(pair_ref),
          @lib.Expr::new([
            @lib.Instruction::struct_new_default(pair),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
        @lib.Instruction::drop(),
      ],
    ),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("struct.new_default"), msg=pretty)
  assert_false(pretty.contains("struct.get"), msg=pretty)
}

///|
test "heap2local v131 scalarizes sequential branch-target array candidates" {
  let array = @lib.TypeIdx::new(0U)
  let array_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(array)),
  )
  let optimized = heap2local_run_module(
    heap2local_module_with_heap_type(
      heap2local_i32_array_type(),
      [],
      [
        @lib.ValType::ref_null(@lib.HeapType::new(array)),
        @lib.ValType::ref_null(@lib.HeapType::new(array)),
      ],
      [
        @lib.Instruction::block(
          @lib.BlockType::val_type(array_ref),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_new_default(array),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::array_get(array),
        @lib.Instruction::drop(),
        @lib.Instruction::block(
          @lib.BlockType::val_type(array_ref),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::array_new_default(array),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::array_get(array),
        @lib.Instruction::drop(),
      ],
    ),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("array.new_default"), msg=pretty)
  assert_false(pretty.contains("array.get"), msg=pretty)
}

///|
test "heap2local v131 scalarizes array allocation flowing through unreachable br_if" {
  // Binaryen v131 stops nullable type-flow adjustment once the condition's
  // return makes the br_if path unreachable. The allocation is still evaluated
  // first and must be scalarized without leaving array traffic or invalid types.
  let decoded = match
    @binary.decode_module(
      Bytes::from_array([
        0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x07, 0x02, 0x5e, 0x7f,
        0x01, 0x60, 0x00, 0x00, 0x03, 0x02, 0x01, 0x01, 0x0a, 0x10, 0x01, 0x0e, 0x00,
        0x02, 0x6a, 0x41, 0x05, 0xfb, 0x07, 0x00, 0x0f, 0x0d, 0x00, 0x0b, 0x1a, 0x0b,
        0x00, 0x30, 0x04, 0x6e, 0x61, 0x6d, 0x65, 0x01, 0x13, 0x01, 0x00, 0x10, 0x75,
        0x6e, 0x72, 0x65, 0x61, 0x63, 0x68, 0x61, 0x62, 0x6c, 0x65, 0x2d, 0x66, 0x6c,
        0x6f, 0x77, 0x03, 0x0a, 0x01, 0x00, 0x01, 0x00, 0x05, 0x62, 0x6c, 0x6f, 0x63,
        0x6b, 0x04, 0x08, 0x01, 0x00, 0x05, 0x61, 0x72, 0x72, 0x61, 0x79,
      ]),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected v131 unreachable-flow fixture decode, got \{err}")
  }
  let optimized = heap2local_run_module(decoded)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("array.new_default"), msg=pretty)
  assert_false(pretty.contains("arrayref"), msg=pretty)
  assert_true(pretty.contains("return"), msg=pretty)
}

///|
test "heap2local leaves parameter-backed ownership unchanged" {
  let pretty = heap2local_pretty_text(
    (
      #| (module
      #|   (type $pair (sub (struct (field (mut i32)) (field (mut i32)))))
      #|   (func (param $ref (ref null $pair))
      #|     (loop $loop
      #|       (drop
      #|         (struct.get $pair 0
      #|           (local.get $ref)))
      #|       (local.set $ref
      #|         (struct.new_default $pair))
      #|       (drop
      #|         (struct.get $pair 0
      #|           (local.get $ref)))
      #|       (br $loop))))
      #|
    ),
  )
  assert_true(pretty.contains("struct.new_default"), msg=pretty)
  assert_true(pretty.contains("struct.get"), msg=pretty)
}
