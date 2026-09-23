///|
test "Binaryen 133 GTO keeps a non-prototype descriptor field at index zero" {
  let output = binaryen133_run_new_pass(
    "(module (rec (type $s (sub (descriptor $d) (struct))) (type $d (sub (describes $s) (struct (field (ref null noextern)) (field externref))))) (import \"env\" \"ext\" (global $ext externref)) (func (export \"run\") (result externref) (extern.convert_any (struct.new_default_desc $s (struct.new $d (ref.null noextern) (global.get $ext))))) (func $use (param (ref $d)) (result externref) (struct.get $d 1 (local.get 0))))",
    "global-type-optimization",
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
