///|
fn heap2local_primary_run(
  text : String,
  requested_passes? : Array[String] = ["heap2local"],
) -> @lib.Module {
  let optimized = match pass_test_run_pipeline(text, requested_passes) {
    Ok(mod_) => mod_
    Err(err) => abort("expected heap2local primary fixture success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => optimized
    Err(err) =>
      abort("expected heap2local primary output to validate, got \{err}")
  }
}

///|
fn heap2local_primary_pretty(
  text : String,
  func_idx? : UInt = 0U,
  requested_passes? : Array[String] = ["heap2local"],
) -> String {
  heap2local_primary_run(text, requested_passes~).pretty_print_func(
    @lib.FuncIdx::new(func_idx),
  )
}

///|
fn heap2local_primary_contains_none(
  pretty : String,
  needles : Array[String],
) -> Bool {
  for needle in needles {
    if pretty.contains(needle) {
      return false
    }
  }
  true
}

///|
fn heap2local_primary_contains_all(
  pretty : String,
  needles : Array[String],
) -> Bool {
  for needle in needles {
    if !pretty.contains(needle) {
      return false
    }
  }
  true
}

///|
fn heap2local_primary_run_module(
  mod_ : @lib.Module,
  requested_passes? : Array[String] = ["heap2local"],
) -> @lib.Module {
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) => abort("unexpected invalid heap2local primary module: \{err}")
  }
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), requested_passes) {
    Ok(mod_) => mod_
    Err(err) =>
      abort("expected heap2local primary module pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => optimized
    Err(err) =>
      abort("expected heap2local primary module output to validate, got \{err}")
  }
}

///|
fn heap2local_primary_pretty_module(
  mod_ : @lib.Module,
  func_idx? : UInt = 0U,
  requested_passes? : Array[String] = ["heap2local"],
) -> String {
  heap2local_primary_run_module(mod_, requested_passes~).pretty_print_func(
    @lib.FuncIdx::new(func_idx),
  )
}

///|
fn heap2local_primary_module_with_heap_type(
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
fn heap2local_primary_pair_type() -> @lib.RecType {
  @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ]),
    ),
  )
}

///|
fn heap2local_primary_box_type() -> @lib.RecType {
  @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::f64()),
          @lib.Mut::var_(),
        ),
      ]),
    ),
  )
}

///|
fn heap2local_primary_i32_array_type() -> @lib.RecType {
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
test "heap2local primary baseline still rewrites a direct exclusive struct owner" {
  let pair = @lib.TypeIdx::new(0U)
  let ref_local = @lib.LocalIdx::new(0U)
  let pretty = heap2local_primary_pretty_module(
    heap2local_primary_module_with_heap_type(
      heap2local_primary_pair_type(),
      [@lib.ValType::i32()],
      [@lib.ValType::ref_null(@lib.HeapType::new(pair))],
      [
        @lib.Instruction::i32_const(@lib.I32(10)),
        @lib.Instruction::i32_const(@lib.I32(20)),
        @lib.Instruction::struct_new(pair),
        @lib.Instruction::local_set(ref_local),
        @lib.Instruction::local_get(ref_local),
        @lib.Instruction::i32_const(@lib.I32(30)),
        @lib.Instruction::struct_set(pair, @lib.U32(1U)),
        @lib.Instruction::local_get(ref_local),
        @lib.Instruction::struct_get(pair, @lib.U32(1U)),
      ],
    ),
  )
  assert_true(
    heap2local_primary_contains_none(pretty, [
      "struct.new", "struct.get", "struct.set",
    ]),
    msg=pretty,
  )
  assert_true(
    heap2local_primary_contains_all(pretty, ["local.set", "local.get"]),
    msg=pretty,
  )
}

///|
test "heap2local primary transforms exclusive local copy chains like Binaryen" {
  let pretty = heap2local_primary_pretty(
    (
      #| (module
      #|   (type $box (sub (struct (field (mut i32)) (field (mut f64)))))
      #|   (func (result f64)
      #|     (local $ref (ref null $box))
      #|     (local $copy (ref null $box))
      #|     (local.set $ref
      #|       (struct.new_default $box))
      #|     (local.set $copy
      #|       (local.get $ref))
      #|     (struct.get $box 1
      #|       (local.get $copy))))
      #|
    ),
  )
  assert_true(
    heap2local_primary_contains_none(pretty, [
      "struct.new_default", "struct.get",
    ]),
    msg=pretty,
  )
}

///|
test "heap2local primary transforms tee owners that flow directly into struct access" {
  let pretty = heap2local_primary_pretty(
    (
      #| (module
      #|   (type $box (sub (struct (field (mut i32)) (field (mut f64)))))
      #|   (func (result i32)
      #|     (local $ref (ref null $box))
      #|     (struct.get $box 0
      #|       (local.tee $ref
      #|         (struct.new_default $box)))))
      #|
    ),
  )
  assert_true(
    heap2local_primary_contains_none(pretty, [
      "struct.new_default", "struct.get",
    ]),
    msg=pretty,
  )
}

///|
test "heap2local primary transforms block value flow that stays exclusive" {
  let pretty = heap2local_primary_pretty(
    (
      #| (module
      #|   (type $box (sub (struct (field (mut i32)) (field (mut f64)))))
      #|   (func (result f64)
      #|     (local $ref (ref null $box))
      #|     (local.set $ref
      #|       (struct.new_default $box))
      #|     (struct.get $box 1
      #|       (block (result (ref null $box))
      #|         (drop (ref.null $box))
      #|         (local.get $ref)))))
      #|
    ),
  )
  assert_true(
    heap2local_primary_contains_none(pretty, [
      "struct.new_default", "struct.get",
    ]),
    msg=pretty,
  )
}

///|
test "heap2local primary removes ref.as_non_null when the value is the optimized allocation" {
  let pretty = heap2local_primary_pretty(
    (
      #| (module
      #|   (type $box (sub (struct (field (mut i32)) (field (mut f64)))))
      #|   (func (result i32)
      #|     (local $ref (ref null $box))
      #|     (local.set $ref
      #|       (struct.new_default $box))
      #|     (struct.get $box 0
      #|       (ref.as_non_null
      #|         (local.get $ref)))))
      #|
    ),
  )
  assert_true(
    heap2local_primary_contains_none(pretty, [
      "struct.new_default", "struct.get", "ref.as_non_null",
    ]),
    msg=pretty,
  )
}

///|
test "heap2local primary folds ref.eq against a nonescaping struct allocation to zero" {
  let pretty = heap2local_primary_pretty(
    (
      #| (module
      #|   (type $box (sub (struct (field (mut i32)) (field (mut f64)))))
      #|   (func (result i32)
      #|     (ref.eq
      #|       (struct.new $box
      #|         (i32.const 0)
      #|         (f64.const 0))
      #|       (ref.null eq))))
      #|
    ),
  )
  assert_true(
    heap2local_primary_contains_none(pretty, ["struct.new", "ref.eq"]),
    msg=pretty,
  )
  assert_true(heap2local_primary_contains_all(pretty, ["I32(0)"]), msg=pretty)
}

///|
test "heap2local primary removes successful ref.cast on an optimized struct allocation" {
  let box = @lib.TypeIdx::new(0U)
  let temp = @lib.LocalIdx::new(0U)
  let pretty = heap2local_primary_pretty_module(
    heap2local_primary_module_with_heap_type(
      heap2local_primary_box_type(),
      [@lib.ValType::i32()],
      [@lib.ValType::anyref()],
      [
        @lib.Instruction::i32_const(@lib.I32(11)),
        @lib.Instruction::f64_const(@lib.F64(0.0)),
        @lib.Instruction::struct_new(box),
        @lib.Instruction::local_tee(temp),
        @lib.Instruction::ref_cast(false, @lib.HeapType::new(box)),
        @lib.Instruction::struct_get(box, @lib.U32(0U)),
      ],
    ),
  )
  assert_true(
    heap2local_primary_contains_none(pretty, [
      "struct.new", "struct.get", "ref.cast",
    ]),
    msg=pretty,
  )
}

///|
test "heap2local primary supports descriptor-bearing struct.new_default_desc and ref.get_desc" {
  let pretty = heap2local_primary_pretty(
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
  assert_true(
    heap2local_primary_contains_none(pretty, [
      "struct.new_default_desc", "ref.get_desc",
    ]),
    msg=pretty,
  )
}

///|
test "heap2local primary folds fresh multi-field struct reference null tests" {
  let pretty = heap2local_primary_pretty_module(
    pass_test_module_from_wat(
      (
        #|(module
        #|  (type $inner (struct))
        #|  (type $outer (struct (field (ref null $inner)) (field i32)))
        #|  (func (result i32)
        #|    (ref.is_null
        #|      (struct.get $outer 0
        #|        (struct.new $outer
        #|          (struct.new_default $inner)
        #|          (i32.const 42))))))
        #|,
      ),
    ),
  )
  assert_true(pretty.contains("I32(0)"), msg=pretty)
  assert_true(
    heap2local_primary_contains_none(pretty, [
      "struct.get", "struct.new", "ref.is_null",
    ]),
    msg=pretty,
  )
}

///|
test "heap2local primary folds fresh struct reads through extern any roundtrips" {
  let input = match
    @binary.decode_module(
      Bytes::from_array([
        0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x09, 0x02, 0x5f, 0x01,
        0x7f, 0x00, 0x60, 0x00, 0x01, 0x7f, 0x03, 0x02, 0x01, 0x01, 0x07, 0x14, 0x01,
        0x10, 0x73, 0x74, 0x72, 0x75, 0x63, 0x74, 0x2d, 0x72, 0x6f, 0x75, 0x6e, 0x64,
        0x74, 0x72, 0x69, 0x70, 0x00, 0x00, 0x0a, 0x15, 0x01, 0x13, 0x00, 0x41, 0xcd,
        0x00, 0xfb, 0x00, 0x00, 0xfb, 0x1b, 0xfb, 0x1a, 0xfb, 0x16, 0x00, 0xfb, 0x02,
        0x00, 0x00, 0x0b,
      ]),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected extern any roundtrip fixture decode, got \{err}")
  }
  let pretty = heap2local_primary_pretty_module(input)
  assert_true(pretty.contains("I32(77)"), msg=pretty)
  assert_true(
    heap2local_primary_contains_none(pretty, [
      "struct.new", "struct.get", "extern.convert_any", "any.convert_extern",
    ]),
    msg=pretty,
  )
}

///|
test "heap2local primary folds nested fresh struct cast and ref.test chains" {
  let input = match
    @binary.decode_module(
      Bytes::from_array([
        0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x0d, 0x03, 0x5f, 0x02,
        0x6e, 0x00, 0x6e, 0x00, 0x5f, 0x00, 0x60, 0x00, 0x01, 0x7f, 0x03, 0x02, 0x01,
        0x02, 0x07, 0x05, 0x01, 0x01, 0x66, 0x00, 0x00, 0x0a, 0x21, 0x01, 0x1f, 0x00,
        0xfb, 0x00, 0x01, 0xd0, 0x6c, 0xfb, 0x00, 0x00, 0x41, 0x02, 0xfb, 0x1c, 0xfb,
        0x00, 0x00, 0xfb, 0x02, 0x00, 0x00, 0xfb, 0x17, 0x00, 0xfb, 0x02, 0x00, 0x00,
        0xfb, 0x15, 0x01, 0x0b,
      ]),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected nested fresh struct fixture decode, got \{err}")
  }
  let pretty = heap2local_primary_pretty_module(input)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(
    heap2local_primary_contains_none(pretty, [
      "struct.new", "struct.get", "ref.cast", "ref.test",
    ]),
    msg=pretty,
  )
}

///|
test "heap2local primary lowers constant-size array.new_default through array.get" {
  let array = @lib.TypeIdx::new(0U)
  let ref_local = @lib.LocalIdx::new(0U)
  let pretty = heap2local_primary_pretty_module(
    heap2local_primary_module_with_heap_type(
      heap2local_primary_i32_array_type(),
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
  assert_true(
    heap2local_primary_contains_none(pretty, ["array.new_default", "array.get"]),
    msg=pretty,
  )
}

///|
test "heap2local primary lowers local.tee array allocation through set and get" {
  let array = @lib.TypeIdx::new(0U)
  let ref_local = @lib.LocalIdx::new(0U)
  let pretty = heap2local_primary_pretty_module(
    heap2local_primary_module_with_heap_type(
      heap2local_primary_i32_array_type(),
      [@lib.ValType::i32()],
      [@lib.ValType::ref_null(@lib.HeapType::new(array))],
      [
        @lib.Instruction::i32_const(@lib.I32(3)),
        @lib.Instruction::array_new_default(array),
        @lib.Instruction::local_tee(ref_local),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::i32_const(@lib.I32(42)),
        @lib.Instruction::array_set(array),
        @lib.Instruction::local_get(ref_local),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::array_get(array),
      ],
    ),
  )
  assert_true(
    heap2local_primary_contains_none(pretty, [
      "array.new_default", "array.set", "array.get",
    ]),
    msg=pretty,
  )
}

///|
test "heap2local primary sign-extends positive packed bit patterns" {
  let fixtures = [
    (@lib.PackType::i8(), @lib.I32(128), @lib.Instruction::i32_extend8s()),
    (@lib.PackType::i16(), @lib.I32(32768), @lib.Instruction::i32_extend16s()),
  ]
  for fixture in fixtures {
    let array = @lib.TypeIdx::new(0U)
    let ref_local = @lib.LocalIdx::new(0U)
    let input = heap2local_primary_module_with_heap_type(
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::array(
            @lib.FieldType::new(
              @lib.StorageType::pack_type(fixture.0),
              @lib.Mut::var_(),
            ),
          ),
        ),
      ),
      [@lib.ValType::i32()],
      [@lib.ValType::ref_null(@lib.HeapType::new(array))],
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::array_new_default(array),
        @lib.Instruction::local_tee(ref_local),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::i32_const(fixture.1),
        @lib.Instruction::array_set(array),
        @lib.Instruction::local_get(ref_local),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::array_get_s(array),
      ],
    )
    let optimized = heap2local_primary_run_module(input)
    match optimized.code_sec {
      Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) =>
        assert_true(body.contains(fixture.2), msg="\{body}")
      _ => fail("expected one packed heap2local function")
    }
  }
}

///|
test "heap2local primary lowers non-null array locals through set and get" {
  let input = match
    @binary.decode_module(
      Bytes::from_array([
        0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x5e, 0x7f,
        0x01, 0x60, 0x00, 0x01, 0x7f, 0x03, 0x02, 0x01, 0x01, 0x0a, 0x1e, 0x01, 0x1c,
        0x01, 0x01, 0x64, 0x00, 0x41, 0x03, 0xfb, 0x07, 0x00, 0x21, 0x00, 0x20, 0x00,
        0x41, 0x01, 0x41, 0x2a, 0xfb, 0x0e, 0x00, 0x20, 0x00, 0x41, 0x01, 0xfb, 0x0b,
        0x00, 0x0b,
      ]),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected non-null array fixture decode, got \{err}")
  }
  let pretty = heap2local_primary_pretty_module(input)
  assert_true(
    heap2local_primary_contains_none(pretty, [
      "array.new_default", "array.set", "array.get",
    ]),
    msg=pretty,
  )
}

///|
test "heap2local primary lowers constant-size array.new with repeated initializer" {
  let array = @lib.TypeIdx::new(0U)
  let ref_local = @lib.LocalIdx::new(0U)
  let pretty = heap2local_primary_pretty_module(
    heap2local_primary_module_with_heap_type(
      heap2local_primary_i32_array_type(),
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
  assert_true(
    heap2local_primary_contains_none(pretty, ["array.new", "array.get"]),
    msg=pretty,
  )
}

///|
test "heap2local primary lowers array.new_fixed with constant index set and get" {
  let array = @lib.TypeIdx::new(0U)
  let ref_local = @lib.LocalIdx::new(0U)
  let pretty = heap2local_primary_pretty_module(
    heap2local_primary_module_with_heap_type(
      heap2local_primary_i32_array_type(),
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
  assert_true(
    heap2local_primary_contains_none(pretty, [
      "array.new_fixed", "array.set", "array.get",
    ]),
    msg=pretty,
  )
}

///|
test "heap2local primary folds array ref.test to a constant" {
  let array = @lib.TypeIdx::new(0U)
  let pretty = heap2local_primary_pretty_module(
    heap2local_primary_module_with_heap_type(
      heap2local_primary_i32_array_type(),
      [@lib.ValType::i32()],
      [],
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::array_new_default(array),
        @lib.Instruction::ref_test(false, @lib.HeapType::new(array)),
      ],
    ),
  )
  assert_true(
    heap2local_primary_contains_none(pretty, ["array.new_default", "ref.test"]),
    msg=pretty,
  )
  assert_true(heap2local_primary_contains_all(pretty, ["I32(1)"]), msg=pretty)
}

///|
test "heap2local primary leaves call escapes unchanged" {
  let input =
    #| (module
    #|   (type $box (sub (struct (field (mut i32)) (field (mut f64)))))
    #|   (import "env" "sink" (func $sink (param (ref null $box))))
    #|   (func (result f64)
    #|     (local $ref (ref null $box))
    #|     (local.set $ref
    #|       (struct.new_default $box))
    #|     (call $sink
    #|       (local.get $ref))
    #|     (struct.get $box 1
    #|       (local.get $ref))))
    #|
  let pretty = heap2local_primary_pretty(input, func_idx=1U)
  assert_true(
    heap2local_primary_contains_all(pretty, ["struct.new_default", "struct.get"]),
    msg=pretty,
  )
}

///|
test "heap2local primary leaves mixed-provenance struct gets unchanged" {
  let pretty = heap2local_primary_pretty(
    (
      #| (module
      #|   (type $box (sub (struct (field (mut i32)) (field (mut f64)))))
      #|   (func (param $x i32) (result f64)
      #|     (local $ref (ref null $box))
      #|     (local.set $ref
      #|       (struct.new_default $box))
      #|     (if (local.get $x)
      #|       (then
      #|         (local.set $ref
      #|           (ref.null $box))))
      #|     (struct.get $box 1
      #|       (local.get $ref))))
      #|
    ),
  )
  assert_true(
    heap2local_primary_contains_all(pretty, ["struct.new_default", "struct.get"]),
    msg=pretty,
  )
}

///|
test "heap2local primary leaves nonconstant array sizes unchanged" {
  let array = @lib.TypeIdx::new(0U)
  let ref_local = @lib.LocalIdx::new(0U)
  let size_local = @lib.LocalIdx::new(1U)
  let pretty = heap2local_primary_pretty_module(
    heap2local_primary_module_with_heap_type(
      heap2local_primary_i32_array_type(),
      [@lib.ValType::i32()],
      [@lib.ValType::ref_null(@lib.HeapType::new(array)), @lib.ValType::i32()],
      [
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::local_set(size_local),
        @lib.Instruction::local_get(size_local),
        @lib.Instruction::array_new_default(array),
        @lib.Instruction::local_set(ref_local),
        @lib.Instruction::local_get(ref_local),
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::array_get(array),
      ],
    ),
  )
  assert_true(
    heap2local_primary_contains_all(pretty, ["array.new_default", "array.get"]),
    msg=pretty,
  )
}

///|
test "heap2local primary leaves loop-carried param and local provenance unchanged" {
  let pretty = heap2local_primary_pretty(
    (
      #| (module
      #|   (type $box (sub (struct (field (mut i32)) (field (mut f64)))))
      #|   (func (param $ref (ref null $box))
      #|     (loop $loop
      #|       (drop
      #|         (struct.get $box 0
      #|           (local.get $ref)))
      #|       (local.set $ref
      #|         (struct.new_default $box))
      #|       (drop
      #|         (struct.get $box 0
      #|           (local.get $ref)))
      #|       (br $loop))))
      #|
    ),
  )
  assert_true(
    heap2local_primary_contains_all(pretty, ["struct.new_default", "struct.get"]),
    msg=pretty,
  )
}
