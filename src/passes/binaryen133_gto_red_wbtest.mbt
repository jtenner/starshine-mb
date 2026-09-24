///|
fn binaryen133_run_gto(source : String) -> @lib.Module raise {
  let input = match @wast.wast_to_binary_module(source) {
    Ok(m) => m
    Err(e) => fail("parse: \{e}")
  }
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(e) => fail("invalid: \{e}")
  }
  binaryen133_run_gto_module(input)
}

///|
fn binaryen133_run_gto_module(input : @lib.Module) -> @lib.Module raise {
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
test "Binaryen 133 GTO removes names belonging to deleted fields" {
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
  let fields = cl_module_subtypes(output).filter(fn(t) {
    t.get_comptype() is @lib.StructCompType(_)
  })
  let fields = match fields[0].get_comptype() {
    @lib.StructCompType(f) => f
    _ => fail("expected struct")
  }
  assert_eq(fields.length(), 0)
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

///|
test "Binaryen 133 GTO prunes inherited fields and makes surviving reads immutable" {
  let output = binaryen133_run_gto(
    "(module (type $base (sub (struct (field (mut i32))))) (type $mid (sub $base (struct (field (mut i32)) (field (mut i32))))) (type $leaf (sub final $mid (struct (field (mut i32)) (field (mut i32)) (field (mut i32))))) (func (export \"run\") (result i32) (struct.get $leaf 2 (struct.new $leaf (i32.const 1) (i32.const 2) (i32.const 3)))))",
  )
  let structs = cl_module_subtypes(output).filter(fn(t) {
    t.get_comptype() is @lib.StructCompType(_)
  })
  assert_eq(structs.length(), 3)
  for index, subtype in structs {
    let fields = match subtype.get_comptype() {
      @lib.StructCompType(fields) => fields
      _ => fail("expected struct")
    }
    assert_eq(fields.length(), if index == 2 { 1 } else { 0 })
    if index == 2 {
      assert_true(fields[0] is @lib.FieldType(_, @lib.Const))
    }
  }
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(body.any(fn(i) { i is @lib.StructGet(_, @lib.U32(0U)) }))
  assert_eq(body.filter(fn(i) { i is @lib.I32Const(_) }).length(), 1)
}

///|
test "Binaryen 133 GTO removed writes preserve receiver null traps and value effects" {
  let output = binaryen133_run_gto_write(
    "(module (type $s (struct (field (mut i32)))) (global $g (mut i32) (i32.const 0)) (func $value (result i32) (global.set $g (i32.const 9)) (i32.const 1)) (func (export \"run\") ref.null $s call $value drop drop))",
  )
  let types = cl_module_subtypes(output)
  match
    types.filter(fn(t) { t.get_comptype() is @lib.StructCompType(_) })[0].get_comptype() {
    @lib.StructCompType(fields) => assert_eq(fields.length(), 0)
    _ => fail("expected struct")
  }
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_true(body.any(fn(i) { i is @lib.RefAsNonNull }))
  assert_true(body.any(fn(i) { i is @lib.Call(_) }))
  assert_false(body.any(fn(i) { i is @lib.StructSet(_, _) }))
}

///|
test "Binaryen 133 GTO preserves mutable ancestor fields read by a subtype" {
  let output = binaryen133_run_gto_write(
    "(module (type $base (sub (struct (field (mut i32))))) (type $leaf (sub final $base (struct (field (mut i32))))) (func (export \"run\") (result i32) (local $r (ref null $leaf)) (local.set $r (struct.new $leaf (i32.const 1))) local.get $r i32.const 9 drop drop (struct.get $leaf 0 (local.get $r))))",
  )
  for subtype in cl_module_subtypes(output) {
    match subtype.get_comptype() {
      @lib.StructCompType(fields) => {
        assert_eq(fields.length(), 1)
        assert_true(fields[0] is @lib.FieldType(_, @lib.Var))
      }
      _ => ()
    }
  }
}

///|
fn binaryen133_run_gto_write(source : String) -> @lib.Module raise {
  let input = pass_test_module_from_wat(source)
  let funcs = input.code_sec.unwrap().0.map(fn(f) {
    let @lib.Func(locals, @lib.Expr(body)) = f
    let out : Array[@lib.Instruction] = []
    let mut i = 0
    while i < body.length() {
      if i + 1 < body.length() &&
        body[i] is @lib.Drop &&
        body[i + 1] is @lib.Drop {
        out.push(
          @lib.Instruction::struct_set(@lib.TypeIdx::new(0U), @lib.U32::new(0U)),
        )
        i += 2
      } else {
        out.push(body[i])
        i += 1
      }
    }
    @lib.Func::new(locals, @lib.Expr::new(out))
  })
  let input = input.with_code_sec(@lib.CodeSec::new(funcs))
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(e) => fail("invalid write fixture: \{e}")
  }
  binaryen133_run_gto_module(input)
}

///|
test "Binaryen 133 GTO preserves distinct private struct identities after pruning" {
  let input = pass_test_module_from_wat(
    "(module (type $a (struct (field i32))) (type $b (struct (field i64))) (func (export \"run\") (result i32) (struct.new $a (i32.const 3)) drop i32.const 0))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  ignore(body.pop())
  ignore(body.pop())
  body.push(
    @lib.Instruction::ref_test(false, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
  )
  let input = input.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]),
  )
  assert_true(@validate.validate_module(input).is_ok())
  let output = binaryen133_run_gto_module(input)
  let groups = output.type_sec.unwrap().0
  assert_true(
    groups.any(fn(g) {
      match g {
        @lib.GroupRecType(ts) =>
          ts
          .filter(fn(t) { t.get_comptype() is @lib.StructCompType([]) })
          .length() ==
          2
        _ => false
      }
    }),
  )
}

///|
test "Binaryen 133 GTO removes unused types before regrouping private identities" {
  let output = binaryen133_run_gto(
    "(module (type $unused (struct (field i64))) (type $used (struct (field i32))) (func (export \"run\") (result i32) (drop (struct.new $used (i32.const 7))) (i32.const 9)))",
  )
  let structs = cl_module_subtypes(output).filter(fn(t) {
    t.get_comptype() is @lib.StructCompType(_)
  })
  assert_eq(structs.length(), 1)
  assert_true(structs[0].get_comptype() is @lib.StructCompType([]))
}

///|
test "Binaryen 133 GTO orders private subtype groups by IR use and dependencies" {
  // Saved campaign-gc-ref-subtypes case: the independent array and sibling
  // distinguish queue ordering from a depth-first type-index traversal.
  let input = @binary.decode_module(
    Bytes::from_array([
      0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x2d, 0x06, 0x60, 0x00,
      0x01, 0x7f, 0x50, 0x00, 0x5f, 0x01, 0x7f, 0x01, 0x50, 0x01, 0x01, 0x5f, 0x02,
      0x7f, 0x01, 0x7f, 0x01, 0x4f, 0x01, 0x01, 0x5f, 0x03, 0x7f, 0x01, 0x7f, 0x01,
      0x7e, 0x01, 0x4f, 0x01, 0x02, 0x5f, 0x03, 0x7f, 0x01, 0x7f, 0x01, 0x7f, 0x01,
      0x5e, 0x7f, 0x01, 0x03, 0x02, 0x01, 0x00, 0x07, 0x07, 0x01, 0x03, 0x72, 0x75,
      0x6e, 0x00, 0x00, 0x0a, 0x29, 0x01, 0x27, 0x02, 0x01, 0x63, 0x01, 0x01, 0x63,
      0x05, 0x41, 0xdd, 0x27, 0x41, 0xa7, 0xed, 0x01, 0x41, 0x8d, 0xde, 0x00, 0xfb,
      0x00, 0x04, 0x21, 0x00, 0x20, 0x00, 0xfb, 0x14, 0x03, 0x1a, 0x20, 0x00, 0xfb,
      0x16, 0x04, 0xfb, 0x02, 0x04, 0x02, 0x0b,
    ]),
  ).unwrap()
  let output = binaryen133_run_gto_module(input)
  let groups = output.type_sec.unwrap().0
  let group = groups.filter(fn(g) { g is @lib.GroupRecType(_) })[0]
  let types = match group {
    @lib.GroupRecType(ts) => ts
    _ => fail("expected private recursion group")
  }
  assert_eq(types.length(), 5)
  assert_true(types[4].get_comptype() is @lib.ArrayCompType(_))
  assert_true(types[1] is @lib.SubType(false, _, _, _))
  assert_true(types[2] is @lib.SubType(true, _, _, _))
  match types[3].get_comptype() {
    @lib.StructCompType(fields) => assert_eq(fields.length(), 1)
    _ => fail("expected leaf struct")
  }
}
