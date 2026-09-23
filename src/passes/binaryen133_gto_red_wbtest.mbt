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
