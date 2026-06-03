///|
fn gsi_test_run(input : String, closed_world : Bool) -> @lib.Module raise {
  let options = if closed_world {
    HotPipelineOptions::new(closed_world=true)
  } else {
    HotPipelineOptions::new()
  }
  match pass_test_run_pipeline(input, ["global-struct-inference"], options~) {
    Ok(mod_) => mod_
    Err(err) => fail("expected global-struct-inference success, got \{err}")
  }
}

///|
fn gsi_test_pretty(input : String, closed_world : Bool) -> String raise {
  gsi_test_run(input, closed_world).pretty_print_func(@lib.FuncIdx::new(0U))
}

///|
fn gsi_assert_folded_i32(input : String, expected : String) -> Unit raise {
  let pretty = gsi_test_pretty(input, false)
  assert_false(pretty.contains("struct.get"), msg=pretty)
  assert_true(pretty.contains(expected), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
}

///|
test "global-struct-inference folds direct immutable global fields in open world" {
  let input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (i32.const 7)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  gsi_assert_folded_i32(input, "I32(7)")

  let exported =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (export "g") (ref $box)
    #|     (struct.new $box
    #|       (i32.const 11)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  gsi_assert_folded_i32(exported, "I32(11)")
}

///|
test "global-struct-inference preserves nullable direct-global traps" {
  let input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (ref null $box)
    #|     (struct.new $box
    #|       (i32.const 8)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let pretty = gsi_test_pretty(input, false)
  assert_false(pretty.contains("struct.get"), msg=pretty)
  assert_true(pretty.contains("ref.as_non_null"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("I32(8)"), msg=pretty)
}

///|
test "global-struct-inference repairs packed i8 and i16 reads by signedness" {
  let signed8 =
    #| (module
    #|   (type $box (sub (struct (field i8))))
    #|   (global $g (ref $box) (struct.new $box (i32.const 255)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get_s $box 0))
    #|
  gsi_assert_folded_i32(signed8, "I32(-1)")

  let unsigned8 =
    #| (module
    #|   (type $box (sub (struct (field i8))))
    #|   (global $g (ref $box) (struct.new $box (i32.const 257)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get_u $box 0))
    #|
  gsi_assert_folded_i32(unsigned8, "I32(1)")

  let signed16 =
    #| (module
    #|   (type $box (sub (struct (field i16))))
    #|   (global $g (ref $box) (struct.new $box (i32.const 65535)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get_s $box 0))
    #|
  gsi_assert_folded_i32(signed16, "I32(-1)")

  let unsigned16 =
    #| (module
    #|   (type $box (sub (struct (field i16))))
    #|   (global $g (ref $box) (struct.new $box (i32.const 65537)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get_u $box 0))
    #|
  gsi_assert_folded_i32(unsigned16, "I32(1)")
}

///|
test "global-struct-inference folds default and descriptor constructors" {
  let default_ctor =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (ref $box) (struct.new_default $box))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  gsi_assert_folded_i32(default_ctor, "I32(0)")

  let nullable_ref_default =
    #| (module
    #|   (type $box (sub (struct (field (ref null $box)))))
    #|   (global $g (ref $box) (struct.new_default $box))
    #|   (func (export "read") (result (ref null $box))
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let nullable_ref_pretty = gsi_test_pretty(nullable_ref_default, false)
  assert_false(
    nullable_ref_pretty.contains("struct.get"),
    msg=nullable_ref_pretty,
  )
  assert_true(nullable_ref_pretty.contains("ref.null"), msg=nullable_ref_pretty)

  let desc_ctor =
    #| (module
    #|   (rec
    #|     (type $box
    #|       (descriptor $box_desc)
    #|       (struct (field i32)))
    #|     (type $box_desc
    #|       (describes $box)
    #|       (struct)))
    #|   (global $desc (ref (exact $box_desc)) (struct.new $box_desc))
    #|   (global $g (ref $box)
    #|     (struct.new_desc $box
    #|       (i32.const 9)
    #|       (global.get $desc)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  gsi_assert_folded_i32(desc_ctor, "I32(9)")

  let default_desc_ctor =
    #| (module
    #|   (rec
    #|     (type $box
    #|       (descriptor $box_desc)
    #|       (struct (field i32)))
    #|     (type $box_desc
    #|       (describes $box)
    #|       (struct)))
    #|   (global $desc (ref (exact $box_desc)) (struct.new $box_desc))
    #|   (global $g (ref $box)
    #|     (struct.new_default_desc $box
    #|       (global.get $desc)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  gsi_assert_folded_i32(default_desc_ctor, "I32(0)")
}

///|
test "global-struct-inference leaves unsafe globals and mutable fields unchanged" {
  let mutable_field =
    #| (module
    #|   (type $box (sub (struct (field (mut i32)))))
    #|   (global $g (ref $box) (struct.new $box (i32.const 7)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let mutable_field_pretty = gsi_test_pretty(mutable_field, false)
  assert_true(
    mutable_field_pretty.contains("struct.get"),
    msg=mutable_field_pretty,
  )

  let mutable_global =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (mut (ref $box)) (struct.new $box (i32.const 7)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let mutable_global_pretty = gsi_test_pretty(mutable_global, false)
  assert_true(
    mutable_global_pretty.contains("struct.get"),
    msg=mutable_global_pretty,
  )

  let imported_global =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (import "env" "g" (global $g (ref $box)))
    #|   (func (export "read") (result i32)
    #|     global.get $g
    #|     struct.get $box 0))
    #|
  let imported_global_pretty = gsi_test_pretty(imported_global, false)
  assert_true(
    imported_global_pretty.contains("struct.get"),
    msg=imported_global_pretty,
  )
}

///|
test "global-struct-inference leaves non-global ref producers unchanged" {
  let input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (ref $box)
    #|     (struct.new $box
    #|       (i32.const 7)))
    #|   (func (export "read") (param (ref $box)) (result i32)
    #|     local.get 0
    #|     struct.get $box 0))
    #|
  let optimized = gsi_test_run(input, true)

  assert_true(
    optimized.pretty_print_func(@lib.FuncIdx::new(0U)).contains("struct.get"),
  )
}
