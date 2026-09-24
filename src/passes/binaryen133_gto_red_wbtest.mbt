///|
fn binaryen133_run_gto(source : String) -> @lib.Module raise {
  let input = pass_test_module_from_wat(source)
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(closed_world=true), [
      "global-type-optimization",
    ]) {
    Ok(output) => output
    Err(err) => fail("Binaryen 133 descriptor GTO is unavailable: \{err}")
  }
  assert_true(@validate.validate_module(output).is_ok())
  output
}

///|
test "Binaryen 133 GTO removes an unread private struct field" {
  let output = binaryen133_run_gto(
    "(module (type $t (struct (field (mut i32)))) (func (export \"run\") (result i32) (drop (struct.new $t (i32.const 1))) (i32.const 7)))",
  )
  let mut field_count = -1
  for subtype in cl_module_subtypes(output) {
    match subtype.get_comptype() {
      @lib.StructCompType(fields) => field_count = fields.length()
      _ => ()
    }
  }
  assert_eq(field_count, 0)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(body.any(fn(instr) { instr is @lib.StructNewDefault(_) }))
  assert_true(body[0] is @lib.StructNewDefault(_))
}

///|
test "Binaryen 133 GTO keeps effects of an unread constructor field" {
  let output = binaryen133_run_gto(
    "(module (type $t (struct (field (mut i32)))) (global $g (mut i32) (i32.const 0)) (func $effect (result i32) (global.set $g (i32.const 9)) (i32.const 1)) (func (export \"run\") (result i32) (drop (struct.new $t (call $effect))) (global.get $g)))",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_true(body.any(fn(instr) { instr is @lib.StructNewDefault(_) }))
  assert_eq(
    ca_test_opcode_count(output, @lib.Instruction::call(@lib.FuncIdx::new(0U))),
    1,
  )
}

///|
test "Binaryen 133 GTO intentionally keeps named fields until name map repair" {
  let input = pass_test_module_from_wat(
    "(module (type $t (struct (field (mut i32)))) (func (export \"run\") (result i32) (drop (struct.new $t (i32.const 1))) (i32.const 7)))",
  ).with_name_sec(
    @lib.NameSec::new(
      field_names=Some(
        @lib.IndirectNameMap::new([
          @lib.IndirectNameAssoc::new(
            0U,
            @lib.NameMap::new([
              @lib.NameAssoc::new(0U, @lib.Name::from_string("value")),
            ]),
          ),
        ]),
      ),
    ),
  )
  assert_true(input.name_sec.unwrap().field_names is Some(_))
  let output = match
    run_hot_pipeline(input, HotPipelineOptions::new(closed_world=true), [
      "global-type-optimization",
    ]) {
    Ok(output) => output
    Err(err) => fail("named-field GTO boundary failed: \{err}")
  }
  let @lib.TypeSec(types) = output.type_sec.unwrap()
  let fields = match types[0] {
    @lib.SingleRecType(subtype) =>
      match subtype.get_comptype() {
        @lib.StructCompType(fields) => fields
        _ => fail("expected a struct type")
      }
    _ => fail("expected a single struct type")
  }
  assert_eq(fields.length(), 1)
}

///|
test "Binaryen 133 GTO keeps a non-prototype descriptor field at index zero" {
  let output = binaryen133_run_gto(
    "(module (rec (type $s (sub (descriptor $d) (struct))) (type $d (sub (describes $s) (struct (field (ref null noextern)) (field externref))))) (import \"env\" \"ext\" (global $ext externref)) (func (export \"run\") (result externref) (extern.convert_any (struct.new_default_desc $s (struct.new $d (ref.null noextern) (global.get $ext))))) (func $use (param (ref $d)) (result externref) (struct.get $d 1 (local.get 0))))",
  )
  let @lib.TypeSec(types) = output.type_sec.unwrap()
  let subtypes = match types[0] {
    @lib.GroupRecType(subtypes) => subtypes
    _ => fail("expected a recursive descriptor group after GTO")
  }
  let fields = match subtypes[1] {
    @lib.SubType(_, _, _, @lib.StructCompType(fields)) => fields
    @lib.CompTypeSubType(_, @lib.StructCompType(fields)) => fields
    _ => fail("expected a struct descriptor after GTO")
  }
  assert_eq(fields.length(), 2)
  assert_true(
    fields[0]
    is @lib.FieldType(@lib.PackTypeStorageType(@lib.I8PackType), @lib.Const),
  )
}

///|
test "Binaryen 133 GTO inserts inherited placeholders and remaps subtype field reads" {
  let output = binaryen133_run_gto(
    "(module (rec (type $super (sub (descriptor $super-desc) (struct))) (type $super-desc (sub (describes $super) (struct (field i32) (field externref))))) (rec (type $sub (sub $super (descriptor $sub-desc) (struct))) (type $sub-desc (sub $super-desc (describes $sub) (struct (field i32) (field externref))))) (func (export \"run\") (result structref) (struct.new_desc $super (struct.new $super-desc (i32.const 42) (extern.convert_any (struct.new_default $super-desc))))) (func (param (ref $super-desc)) (drop (struct.get $super-desc 1 (local.get 0)))) (func (param (ref $sub-desc)) (drop (struct.get $sub-desc 0 (local.get 0))) (drop (struct.get $sub-desc 1 (local.get 0)))))",
  )
  let group = match output.type_sec.unwrap().0[1] {
    @lib.GroupRecType(group) => group
    _ => fail("expected a recursive subtype descriptor group")
  }
  let fields = match group[1].get_comptype() {
    @lib.StructCompType(fields) => fields
    _ => fail("expected subtype descriptor fields")
  }
  assert_eq(fields.length(), 3)
  assert_true(
    fields[0]
    is @lib.FieldType(@lib.PackTypeStorageType(@lib.I8PackType), @lib.Const),
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[2]
  assert_true(
    body.any(fn(instr) {
      instr is @lib.StructGet(@lib.TypeIdx(3U), @lib.U32(2U))
    }),
  )
}
