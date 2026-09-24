///|
fn binaryen133_run_shared(
  source : String,
  array_len? : Bool = false,
) -> @lib.Module raise {
  let input = match @wast.wast_to_binary_module(source) {
    Ok(m) => m
    Err(e) => fail("parse: \{e}")
  }
  let input = if array_len {
    let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    ignore(body.pop())
    ignore(body.pop())
    body.push(@lib.Instruction::array_len())
    input.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]),
    )
  } else {
    input
  }
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(e) => fail("input: \{e}")
  }
  let output = make_shared_objects_run_module_pass(input)
  match @validate.validate_module(output) {
    Ok(_) => ()
    Err(e) => fail("output: \{e}")
  }
  output
}

///|
test "Binaryen 133 shared objects rewrites array length modules" {
  let output = binaryen133_run_shared(
    "(module (type $a (array (mut i32))) (func (export \"run\") (result i32) (array.new_default $a (i32.const 3)) drop i32.const 0))",
    array_len=true,
  )
  assert_true(
    cl_module_subtypes(output).any(fn(t) {
      t.get_comptype() is @lib.ArrayCompType(_) && t.metadata().is_shared()
    }),
  )
}

///|
test "Binaryen 133 shared objects rewrites imported and defined global references" {
  let output = binaryen133_run_shared(
    "(module (type $s (struct (field i32))) (import \"env\" \"value\" (global $g externref)) (global $copy externref (global.get $g)) (global $obj (mut anyref) (ref.null any)))",
  )
  let imported = match output.import_sec.unwrap().0[0] {
    @lib.Import(_, _, @lib.GlobalExternType(@lib.GlobalType(vt, _))) => vt
    _ => fail("expected global import")
  }
  assert_eq(imported, mso_shared_i31(true))
  let @lib.Global(@lib.GlobalType(copy_type, _), _) = output.global_sec.unwrap().0[0]
  assert_eq(copy_type, mso_shared_i31(true))
  let @lib.Global(@lib.GlobalType(object_type, _), _) = output.global_sec.unwrap().0[1]
  assert_eq(object_type, mso_shared_any(true))
}

///|
test "Binaryen 133 shared objects lowers indirect calls through an index table" {
  let output = binaryen133_run_shared(
    "(module (type $f (func (result i32))) (table 1 funcref) (elem (i32.const 0) func $target) (func $target (type $f) (i32.const 7)) (func (export \"run\") (result i32) (call_indirect (type $f) (i32.const 0))))",
  )
  assert_eq(output.table_sec.unwrap().0.length(), 2)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_true(body.any(fn(i) { i is @lib.TableGet(@lib.TableIdx(0U)) }))
  assert_true(body.any(fn(i) { i is @lib.I31GetU }))
  assert_true(body.any(fn(i) { i is @lib.CallIndirect(_, @lib.TableIdx(1U)) }))
}

///|
test "Binaryen 133 shared objects tests concrete function references through the function table" {
  let input = pass_test_module_from_wat(
    "(module (type $f (func (result i32))) (func $target (type $f) (i32.const 7)) (elem declare func $target) (func (export \"run\") (param funcref) (result i32) (local.get 0) drop i32.const 0))",
  )
  let funcs = input.code_sec.unwrap().0.copy()
  let @lib.Func(locals, @lib.Expr(body)) = funcs[1]
  ignore(body.pop())
  ignore(body.pop())
  body.push(
    @lib.Instruction::ref_test(false, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  funcs[1] = @lib.Func::new(locals, @lib.Expr::new(body))
  let input = input.with_code_sec(@lib.CodeSec::new(funcs))
  assert_true(@validate.validate_module(input).is_ok())
  let output = make_shared_objects_run_module_pass(input)
  assert_eq(output.table_sec.unwrap().0.length(), 1)
  assert_true(@validate.validate_module(output).is_ok())
  assert_eq(
    binaryen133_shared_opcode_count(
      output,
      @lib.Instruction::table_get(@lib.TableIdx::new(0U)),
    ),
    1,
  )
}

///|
test "Binaryen 133 shared objects checks function casts before returning the shared index" {
  let input = pass_test_module_from_wat(
    "(module (type $f (func (result i32))) (func $target (type $f) (i32.const 7)) (elem declare func $target) (func (export \"run\") (param funcref) (local.get 0) drop))",
  )
  let funcs = input.code_sec.unwrap().0.copy()
  let @lib.Func(locals, @lib.Expr(body)) = funcs[1]
  body.insert(
    1,
    @lib.Instruction::ref_cast(false, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  funcs[1] = @lib.Func::new(locals, @lib.Expr::new(body))
  let input = input.with_code_sec(@lib.CodeSec::new(funcs))
  assert_true(@validate.validate_module(input).is_ok())
  let output = make_shared_objects_run_module_pass(input)
  assert_eq(output.table_sec.unwrap().0.length(), 1)
  assert_true(@validate.validate_module(output).is_ok())
  assert_eq(
    binaryen133_shared_opcode_count(
      output,
      @lib.Instruction::table_get(@lib.TableIdx::new(0U)),
    ),
    1,
  )
}

///|
fn binaryen133_shared_opcode_count(
  mod_ : @lib.Module,
  opcode : @lib.Instruction,
) -> Int {
  let count = [0]
  fn visit(expr : @lib.Expr) -> @lib.Expr {
    for instr in expr.0 {
      if instr == opcode {
        count[0] += 1
      }
      ignore(gto_map_children(instr, visit))
    }
    expr
  }
  for @lib.Func(_, body) in mod_.code_sec.unwrap().0 {
    ignore(visit(body))
  }
  count[0]
}

///|
test "Binaryen 133 shared objects refinalizes null-only branch results" {
  for
    branch in [
      @lib.Instruction::br(@lib.LabelIdx::new(0U)),
      @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
      @lib.Instruction::br_table(
        [@lib.LabelIdx::new(0U)],
        @lib.LabelIdx::new(0U),
      ),
    ] {
    let input = pass_test_module_from_wat("(module (func))")
    let body = [
      @lib.Instruction::ref_null(
        @lib.HeapType::abs(@lib.AbsHeapType::no_func()),
      ),
    ]
    if !(branch is @lib.Br(_)) {
      body.push(@lib.Instruction::i32_const(@lib.I32(0)))
    }
    body.push(branch)
    let input = input.with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::funcref()),
              @lib.Expr::new(body),
            ),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
    assert_true(@validate.validate_module(input).is_ok())
    let output = make_shared_objects_run_module_pass(input)
    assert_true(@validate.validate_module(output).is_ok())
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    let result = match body[0] {
      @lib.Block(@lib.ValTypeBlockType(vt), _) => vt
      _ => fail("expected reference block")
    }
    assert_eq(
      result,
      @lib.ValType::ref_type(
        @lib.RefType::new(
          true,
          @lib.HeapType::shared_abs(@lib.AbsHeapType::none()),
        ),
      ),
    )
  }
}

///|
test "Binaryen 133 shared objects lowers null call_ref targets without a function table" {
  let input = pass_test_module_from_wat(
    "(module (type $f (func (param i32) (result i32))) (func (export \"run\") (result i32) (i32.const 9) (ref.null nofunc) drop drop (i32.const 0)))",
  )
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  ignore(body.pop())
  ignore(body.pop())
  ignore(body.pop())
  body.push(@lib.Instruction::call_ref(@lib.TypeIdx::new(0U)))
  let input = input.with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]),
  )
  assert_true(@validate.validate_module(input).is_ok())
  let output = make_shared_objects_run_module_pass(input)
  assert_true(@validate.validate_module(output).is_ok())
  assert_true(output.table_sec is None)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(body.any(fn(i) { i is @lib.Unreachable }))
  assert_false(body.any(fn(i) { i is @lib.CallIndirect(_, _) }))
}

///|
test "Binaryen 133 shared objects preserves export aliases when wrapping externrefs" {
  let output = binaryen133_run_shared(
    "(module (func $f (param externref) (result externref) (local.get 0)) (export \"first\" (func $f)) (export \"second\" (func $f)))",
  )
  let @lib.Export(_, first) = output.export_sec.unwrap().0[0]
  let @lib.Export(_, second) = output.export_sec.unwrap().0[1]
  assert_eq(first, second)
  assert_eq(output.code_sec.unwrap().0.length(), 4)
}

///|
test "Binaryen 133 shared objects refinalizes null branches before unreachable debris" {
  let output = binaryen133_run_shared(
    "(module (func (drop (block (result funcref) (ref.null func) (i32.const 0) (br_table 0 0) (unreachable)))))",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  let result = match body[0] {
    @lib.Block(@lib.ValTypeBlockType(vt), _) => vt
    _ => fail("expected reference block")
  }
  assert_eq(
    result,
    @lib.ValType::ref_type(
      @lib.RefType::new(
        true,
        @lib.HeapType::shared_abs(@lib.AbsHeapType::none()),
      ),
    ),
  )
}

///|
test "Binaryen 133 shared objects refines nested null branch exits" {
  for branch in ["br 1", "i32.const 0 br_table 1 1", "i32.const 1 br_if 1 br 1"] {
    let output = binaryen133_run_shared(
      "(module (func (drop (block (result funcref) (block ref.null func \{branch} unreachable) unreachable))))",
    )
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    let result = match body[0] {
      @lib.Block(@lib.ValTypeBlockType(vt), _) => vt
      _ => fail("expected reference block")
    }
    assert_eq(
      result,
      @lib.ValType::ref_type(
        @lib.RefType::new(
          true,
          @lib.HeapType::shared_abs(@lib.AbsHeapType::none()),
        ),
      ),
    )
  }
}

///|
test "Binaryen 133 shared objects refines i31 if and branch results" {
  let output = binaryen133_run_shared(
    "(module (func (drop (if (result anyref) (i32.const 1) (then (ref.i31 (i32.const 3))) (else (ref.i31 (i32.const 5))))) (drop (block (result anyref) (br 0 (ref.i31 (i32.const 7)))))))",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  let results : Array[@lib.ValType] = []
  for instr in body {
    match instr {
      @lib.If(@lib.ValTypeBlockType(vt), _, _)
      | @lib.Block(@lib.ValTypeBlockType(vt), _) => results.push(vt)
      _ => ()
    }
  }
  assert_eq(results, [mso_shared_i31(false), mso_shared_i31(false)])
}

///|
test "Binaryen 133 shared objects joins null and nonnull i31 control exits" {
  let output = binaryen133_run_shared(
    "(module (func (param i32) (drop (if (result anyref) (local.get 0) (then (ref.null none)) (else (ref.i31 (i32.const 5)))))))",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  let result = match body[1] {
    @lib.If(@lib.ValTypeBlockType(vt), _, _) => vt
    _ => fail("expected reference if")
  }
  assert_eq(result, mso_shared_i31(true))
}
