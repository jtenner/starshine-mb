///|
fn binaryen133_run_new_pass(
  source : String,
  pass : String,
) -> @lib.Module raise {
  let output = match pass_test_run_pipeline(source, [pass]) {
    Ok(output) => output
    Err(err) => fail("Binaryen 133 \{pass} shape is not implemented: \{err}")
  }
  match @validate.validate_module(output) {
    Ok(_) => output
    Err(err) => fail("Binaryen 133 \{pass} produced invalid wasm: \{err}")
  }
}

///|
fn binaryen133_export_count(mod_ : @lib.Module) -> Int {
  match mod_.export_sec {
    Some(@lib.ExportSec(exports)) => exports.length()
    None => 0
  }
}

///|
test "Binaryen 133 tail-call converts a final direct void call" {
  let output = binaryen133_run_new_pass(
    "(module (func $callee) (func (export \"run\") (call $callee)))", "tail-call",
  )
  assert_eq(
    ca_test_opcode_count(
      output,
      @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
    ),
    1,
  )
}

///|
test "Binaryen 133 tail-call converts a direct value call inside return" {
  let output = binaryen133_run_new_pass(
    "(module (func $callee (result i32) (i32.const 7)) (func (export \"run\") (result i32) (return (call $callee))))",
    "tail-call",
  )
  assert_eq(
    ca_test_opcode_count(
      output,
      @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
    ),
    1,
  )
}

///|
test "Binaryen 133 tail-call converts a void call before explicit return" {
  let output = binaryen133_run_new_pass(
    "(module (func $callee) (func (export \"run\") (call $callee) (return)))", "tail-call",
  )
  assert_eq(
    ca_test_opcode_count(
      output,
      @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
    ),
    1,
  )
}

///|
test "Binaryen 133 tail-call accepts a callee result subtype" {
  let output = binaryen133_run_new_pass(
    "(module (type $s (struct)) (func $callee (result (ref $s)) (struct.new_default $s)) (func (export \"run\") (result anyref) (call $callee)))",
    "tail-call",
  )
  assert_eq(
    ca_test_opcode_count(
      output,
      @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
    ),
    1,
  )
}

///|
test "Binaryen 133 tail-call converts both tail if arms" {
  let output = binaryen133_run_new_pass(
    "(module (func $a (result i32) (i32.const 1)) (func $b (result i32) (i32.const 2)) (func (export \"run\") (param i32) (result i32) (if (result i32) (local.get 0) (then (call $a)) (else (call $b)))))",
    "tail-call",
  )
  assert_eq(
    ca_test_opcode_count(
      output,
      @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
    ),
    1,
  )
  assert_eq(
    ca_test_opcode_count(
      output,
      @lib.Instruction::return_call(@lib.FuncIdx::new(1U)),
    ),
    1,
  )
}

///|
test "Binaryen 133 tail-call converts a void call in a one-armed tail if" {
  let output = binaryen133_run_new_pass(
    "(module (func $callee) (func (export \"run\") (param i32) (if (local.get 0) (then (call $callee)))))",
    "tail-call",
  )
  assert_eq(
    ca_test_opcode_count(
      output,
      @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
    ),
    1,
  )
}

///|
test "Binaryen 133 tail-call converts a loop fallthrough call" {
  let output = binaryen133_run_new_pass(
    "(module (func $callee (result i32) (i32.const 7)) (func (export \"run\") (result i32) (loop (result i32) (call $callee))))",
    "tail-call",
  )
  assert_eq(
    ca_test_opcode_count(
      output,
      @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
    ),
    1,
  )
}

///|
test "Binaryen 133 tail-call converts a final call_indirect" {
  let output = binaryen133_run_new_pass(
    "(module (type $sig (func (result i32))) (table 1 funcref) (func $callee (result i32) (i32.const 7)) (elem (i32.const 0) $callee) (func (export \"run\") (result i32) (call_indirect (type $sig) (i32.const 0))))",
    "tail-call",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_true(body.any(fn(instr) { instr is @lib.ReturnCallIndirect(_, _) }))
}

///|
test "Binaryen 133 tail-call converts a final call_ref" {
  let output = binaryen133_run_new_pass(
    "(module (type $sig (func (result i32))) (func $callee (type $sig) (i32.const 7)) (elem declare func $callee) (func (export \"run\") (result i32) (call_ref $sig (ref.func $callee))))",
    "tail-call",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_true(body.any(fn(instr) { instr is @lib.ReturnCallRef(_) }))
}

///|
test "Binaryen 133 tail-call converts a multivalue call" {
  let output = binaryen133_run_new_pass(
    "(module (func $callee (result i32 i64) (i32.const 1) (i64.const 2)) (func (export \"run\") (result i32 i64) (call $callee)))",
    "tail-call",
  )
  assert_eq(
    ca_test_opcode_count(
      output,
      @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
    ),
    1,
  )
}

///|
test "Binaryen 133 tail-call converts a call in a tail br_if value" {
  let output = binaryen133_run_new_pass(
    "(module (func $callee (result i32) (i32.const 7)) (func (export \"run\") (param i32) (result i32) (block $out (result i32) (br_if $out (call $callee) (local.get 0)))))",
    "tail-call",
  )
  assert_eq(
    ca_test_opcode_count(
      output,
      @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
    ),
    1,
  )
}

///|
test "Binaryen 133 tail-call converts a call in an unconditional exit branch" {
  let output = binaryen133_run_new_pass(
    "(module (func $callee (result i32) (i32.const 7)) (func (export \"run\") (result i32) (block $out (result i32) (br $out (call $callee)))))",
    "tail-call",
  )
  assert_eq(
    ca_test_opcode_count(
      output,
      @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
    ),
    1,
  )
}

///|
test "Binaryen 133 tail-call converts a call in an all-tail br_table value" {
  let output = binaryen133_run_new_pass(
    "(module (func $callee (result i32) (i32.const 7)) (func (export \"run\") (param i32) (result i32) (block $out1 (result i32) (block $out2 (result i32) (br_table $out1 $out2 (call $callee) (local.get 0))))))",
    "tail-call",
  )
  assert_eq(
    ca_test_opcode_count(
      output,
      @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
    ),
    1,
  )
}

///|
test "Binaryen 133 tail-call converts a void call before a function exit branch" {
  let output = binaryen133_run_new_pass(
    "(module (func $callee) (func (export \"run\") (param i32) (block $out (if (local.get 0) (then (call $callee) (br $out))) (call $callee))))",
    "tail-call",
  )
  assert_eq(
    ca_test_opcode_count(
      output,
      @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
    ),
    2,
  )
}

///|
test "Binaryen 133 empty-export pass removes a nop body and all aliases" {
  let output = binaryen133_run_new_pass(
    "(module (func $empty (nop)) (export \"one\" (func $empty)) (export \"two\" (func $empty)))",
    "remove-empty-function-exports",
  )
  assert_eq(binaryen133_export_count(output), 0)
  assert_eq(output.code_sec.unwrap().0.length(), 1)
}

///|
test "Binaryen 133 empty-export pass removes an empty block body" {
  let output = binaryen133_run_new_pass(
    "(module (func $empty (block)) (export \"empty\" (func $empty)))", "remove-empty-function-exports",
  )
  assert_eq(binaryen133_export_count(output), 0)
  assert_eq(output.code_sec.unwrap().0.length(), 1)
}

///|
test "Binaryen 133 shared-objects lowers an exported nullable externref" {
  let output = binaryen133_run_new_pass(
    "(module (func (export \"run\") (param externref) (result externref) (local.get 0)))",
    "make-shared-objects",
  )
  assert_true(output.table_sec is Some(_))
  assert_true(output.code_sec.unwrap().0.length() > 1)
}

///|
test "Binaryen 133 shared-objects wraps an imported externref signature" {
  let output = binaryen133_run_new_pass(
    "(module (import \"m\" \"f\" (func $f (param externref) (result externref))) (func (export \"run\") (param externref) (result externref) (call $f (local.get 0))))",
    "make-shared-objects",
  )
  assert_true(output.table_sec is Some(_))
  assert_true(output.code_sec.unwrap().0.length() > 1)
}

///|
test "Binaryen 133 shared-objects lowers a non-null externref export" {
  let output = binaryen133_run_new_pass(
    "(module (func (export \"run\") (param (ref extern)) (result (ref extern)) (local.get 0)))",
    "make-shared-objects",
  )
  assert_true(output.table_sec is Some(_))
  assert_true(output.code_sec.unwrap().0.length() > 1)
}

///|
test "Binaryen 133 shared-objects lowers explicit extern conversion" {
  let output = binaryen133_run_new_pass(
    "(module (func (export \"run\") (param anyref) (result externref) (extern.convert_any (local.get 0))))",
    "make-shared-objects",
  )
  assert_true(output.table_sec is Some(_))
  assert_true(output.code_sec.unwrap().0.length() > 1)
}

///|
test "Binaryen 133 shared-objects lowers explicit any.convert_extern" {
  let output = binaryen133_run_new_pass(
    "(module (func (export \"run\") (param externref) (result anyref) (any.convert_extern (local.get 0))))",
    "make-shared-objects",
  )
  assert_true(output.table_sec is Some(_))
  assert_true(output.code_sec.unwrap().0.length() > 1)
}

///|
test "Binaryen 133 shared-objects makes an ordinary struct type shared" {
  let output = binaryen133_run_new_pass(
    "(module (type $s (struct (field i32))) (func (export \"run\") (result (ref $s)) (struct.new $s (i32.const 1))))",
    "make-shared-objects",
  )
  let subtype = match output.type_sec.unwrap().0[0] {
    @lib.SingleRecType(subtype) => subtype
    _ => fail("expected a single struct type")
  }
  assert_true(subtype.metadata().is_shared())
}

///|
test "Binaryen 133 shared-objects makes an ordinary array type shared" {
  let output = binaryen133_run_new_pass(
    "(module (type $a (array (mut i32))) (func (export \"run\") (param (ref null $a)) (drop (local.get 0))))",
    "make-shared-objects",
  )
  let subtype = match output.type_sec.unwrap().0[0] {
    @lib.SingleRecType(subtype) => subtype
    _ => fail("expected a single array type")
  }
  assert_true(subtype.metadata().is_shared())
}

///|
test "Binaryen 133 shared-objects lowers funcref to shared i31ref" {
  let output = binaryen133_run_new_pass(
    "(module (func $run (param funcref) (result funcref) (local.get 0)))", "make-shared-objects",
  )
  let subtype = match output.type_sec.unwrap().0[0] {
    @lib.SingleRecType(subtype) => subtype
    _ => fail("expected a function type")
  }
  let params = match subtype.get_comptype() {
    @lib.FuncCompType(params, _) => params
    _ => fail("expected a function signature")
  }
  assert_true(
    params[0]
    is @lib.RefTypeValType(
      @lib.HeapTypeRefType(
        _,
        _,
        @lib.SharedAbsHeapTypeHeapType(@lib.I31AbsHeapType)
      )
    ),
  )
}

///|
test "Binaryen 133 shared-objects lowers anyref to shared anyref" {
  let output = binaryen133_run_new_pass(
    "(module (func $run (param anyref) (result anyref) (local.get 0)))", "make-shared-objects",
  )
  let subtype = match output.type_sec.unwrap().0[0] {
    @lib.SingleRecType(subtype) => subtype
    _ => fail("expected a function type")
  }
  let params = match subtype.get_comptype() {
    @lib.FuncCompType(params, _) => params
    _ => fail("expected a function signature")
  }
  assert_true(
    params[0]
    is @lib.RefTypeValType(
      @lib.HeapTypeRefType(
        _,
        _,
        @lib.SharedAbsHeapTypeHeapType(@lib.AnyAbsHeapType)
      )
    ),
  )
}

///|
test "Binaryen 133 shared-objects remaps recursive function self references" {
  let output = binaryen133_run_new_pass(
    "(module (type $f (func (param (ref $f)) (result (ref $f)))) (func $run (type $f) (local.get 0)))",
    "make-shared-objects",
  )
  let subtype = match output.type_sec.unwrap().0[0] {
    @lib.SingleRecType(subtype) => subtype
    _ => fail("expected a recursive function type")
  }
  let params = match subtype.get_comptype() {
    @lib.FuncCompType(params, _) => params
    _ => fail("expected a function signature")
  }
  assert_true(
    params[0]
    is @lib.RefTypeValType(
      @lib.HeapTypeRefType(
        _,
        _,
        @lib.SharedAbsHeapTypeHeapType(@lib.I31AbsHeapType)
      )
    ),
  )
}

///|
test "Binaryen 133 shared-objects remaps a function reference stored in a struct field" {
  let output = binaryen133_run_new_pass(
    "(module (type $f (func)) (type $s (struct (field (ref $f)) (field i32))) (func $f (type $f)) (elem declare func $f) (func (export \"run\") (result (ref $s)) (struct.new $s (ref.func $f) (i32.const 1))))",
    "make-shared-objects",
  )
  let subtype = match output.type_sec.unwrap().0[0] {
    @lib.SingleRecType(subtype) => subtype
    _ => fail("expected a struct type")
  }
  let fields = match subtype.get_comptype() {
    @lib.StructCompType(fields) => fields
    _ => fail("expected struct fields")
  }
  assert_true(subtype.metadata().is_shared())
  assert_true(
    fields[0]
    is @lib.FieldType(
      @lib.ValTypeStorageType(
        @lib.RefTypeValType(
          @lib.HeapTypeRefType(
            _,
            _,
            @lib.SharedAbsHeapTypeHeapType(@lib.I31AbsHeapType)
          )
        )
      ),
      @lib.Const
    ),
  )
}
