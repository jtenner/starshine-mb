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
test "make-shared-objects wraps a multi-result externref import" {
  let output = binaryen133_run_shared(
    (
      #|(module
      #|  (import "m" "pair" (func $pair (result externref i32)))
      #|  (func (result externref i32) (call $pair)))
    ),
  )
  assert_true(output.code_sec.unwrap().0.length() > 1)
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::externref(), @lib.ValType::i32()]),
  )
  assert_eq(body, [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
  let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
  assert_true(@validate.validate_module(decoded).is_ok())
}

///|
test "make-shared-objects wraps a multi-result externref export" {
  let output = binaryen133_run_shared(
    (
      #|(module
      #|  (func (export "pair") (result externref i32)
      #|    (ref.null extern)
      #|    (i32.const 7)))
    ),
  )
  assert_true(output.code_sec.unwrap().0.length() > 1)
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_eq(
    locals,
    @lib.Locals::from_types([mso_shared_i31(true), @lib.ValType::i32()]),
  )
  assert_eq(body, [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
  let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
  assert_true(@validate.validate_module(decoded).is_ok())
}

///|
test "make-shared-objects converts each externref in a three-result import" {
  let output = binaryen133_run_shared(
    (
      #|(module
      #|  (import "m" "triple" (func $triple (result externref i32 externref)))
      #|  (func (result externref i32 externref) (call $triple)))
    ),
  )
  let @lib.Func(locals, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::externref(),
      @lib.ValType::i32(),
      @lib.ValType::externref(),
    ]),
  )
  assert_eq(body, [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::call(@lib.FuncIdx::new(3U)),
  ])
}

///|
test "make-shared-objects wraps a non-null multi-result externref import" {
  let output = binaryen133_run_shared(
    (
      #|(module
      #|  (import "m" "pair" (func $pair (result (ref extern) i32)))
      #|  (func (result (ref extern) i32) (call $pair)))
    ),
  )
  assert_true(output.code_sec.unwrap().0.length() > 1)
  let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
  assert_true(@validate.validate_module(decoded).is_ok())
}

///|
test "make-shared-objects reuses a repeated export boundary signature" {
  let output = binaryen133_run_shared(
    (
      #|(module
      #|  (type $pair (func (result externref i32)))
      #|  (func (export "one") (type $pair)
      #|    (ref.null extern) (i32.const 1))
      #|  (func (export "two") (type $pair)
      #|    (ref.null extern) (i32.const 2)))
    ),
  )
  assert_eq(output.type_sec.unwrap().0.length(), 4)
}

///|
test "Binaryen 133 shared objects lowers typed calls and tail calls through the same function table" {
  for tail in [false, true] {
    let input = pass_test_module_from_wat(
      "(module (type $f (func (result i32))) (func $target (type $f) i32.const 41) (elem declare func $target) (func (result i32) i32.const 0))",
    )
    let functions = input.code_sec.unwrap().0.copy()
    functions[1] = @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([
        @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
        if tail {
          @lib.Instruction::return_call_ref(@lib.TypeIdx::new(0U))
        } else {
          @lib.Instruction::call_ref(@lib.TypeIdx::new(0U))
        },
      ]),
    )
    let input = input.with_code_sec(@lib.CodeSec::new(functions))
    assert_true(@validate.validate_module(input).is_ok())
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "make-shared-objects",
    ]).unwrap()
    assert_true(@validate.validate_module(output).is_ok())
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
    assert_eq(body.length(), 4)
    assert_eq(body[0], @lib.Instruction::i32_const(@lib.I32(0)))
    assert_eq(body[1], @lib.Instruction::ref_i31_shared())
    assert_eq(body[2], @lib.Instruction::i31_get_u())
    assert_eq(
      body[3],
      if tail {
        @lib.Instruction::return_call_indirect(
          @lib.TypeIdx::new(0U),
          @lib.TableIdx::new(0U),
        )
      } else {
        @lib.Instruction::call_indirect(
          @lib.TypeIdx::new(0U),
          @lib.TableIdx::new(0U),
        )
      },
    )
    assert_eq(output.table_sec.unwrap().0.length(), 1)
    let decoded = @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap()
    assert_true(@validate.validate_module(decoded).is_ok())
    assert_eq(decoded.code_sec, output.code_sec)
  }
}

///|
test "Binaryen 133 shared objects preserves imported table indices for indirect tail calls" {
  let output = binaryen133_run_shared(
    "(module (type $f (func (result i32))) (import \"env\" \"memory\" (memory 1)) (import \"env\" \"table\" (table 1 funcref)) (func (result i32) (return_call_indirect (type $f) (i32.const 0))))",
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(body, [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::table_get(@lib.TableIdx::new(0U)),
    @lib.Instruction::i31_get_u(),
    @lib.Instruction::return_call_indirect(
      @lib.TypeIdx::new(0U),
      @lib.TableIdx::new(1U),
    ),
  ])
  assert_eq(output.table_sec.unwrap().0.length(), 1)
  let imported = output.import_sec.unwrap().0[1]
  assert_true(
    imported is @lib.Import(_, _, @lib.TableExternType(@lib.TableType(rt, _))) &&
    @lib.ValType::ref_type(rt) == mso_shared_i31(true),
  )
}

///|
test "Binaryen 133 shared objects preserves packed fields and subtype relationships" {
  let output = binaryen133_run_shared(
    "(module (type $base (sub (struct (field (mut i8))))) (type $child (sub $base (struct (field (mut i8)) (field i16)))))",
  )
  let types = cl_module_subtypes(output)
  assert_eq(types.length(), 2)
  assert_true(types.all(fn(t) { t.metadata().is_shared() }))
  assert_eq(types[1].super_types(), [@lib.TypeIdx::new(0U)])
  match types[1].get_comptype() {
    @lib.StructCompType(fields) => {
      assert_eq(fields.length(), 2)
      assert_eq(
        fields[0],
        @lib.FieldType::new(
          @lib.StorageType::pack_type(@lib.PackType::i8()),
          @lib.Mut::var_(),
        ),
      )
      assert_eq(
        fields[1],
        @lib.FieldType::new(
          @lib.StorageType::pack_type(@lib.PackType::i16()),
          @lib.Mut::const_(),
        ),
      )
    }
    _ => fail("expected shared struct fields")
  }
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
test "make-shared-objects fails closed on concrete function br_on_cast" {
  let input = pass_test_module_from_wat(
    "(module (type $f (func)) (func $target (type $f)) (elem declare func $target) (func (param funcref) (local.get 0) drop))",
  )
  let funcs = input.code_sec.unwrap().0.copy()
  let @lib.Func(locals, _) = funcs[1]
  funcs[1] = @lib.Func::new(
    locals,
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::val_type(
          @lib.ValType::ref_type(
            @lib.RefType::new(false, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
          ),
        ),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::br_on_cast(
            @lib.LabelIdx::new(0U),
            true,
            @lib.HeapType::abs(@lib.AbsHeapType::func()),
            false,
            @lib.HeapType::new(@lib.TypeIdx::new(0U)),
          ),
          @lib.Instruction::drop(),
          @lib.Instruction::unreachable_(),
        ]),
      ),
      @lib.Instruction::drop(),
    ]),
  )
  let input = input.with_code_sec(@lib.CodeSec::new(funcs))
  let validation = @validate.validate_module(input)
  assert_true(validation.is_ok(), msg=@debug.to_string(validation))
  assert_eq(make_shared_objects_run_module_pass(input), input)
}

///|
test "make-shared-objects preserves unsupported string heaps" {
  for
    source in [
      @lib.HeapType::abs(@lib.AbsHeapType::string_()),
      @lib.HeapType::shared_abs(@lib.AbsHeapType::string_()),
    ] {
    assert_eq(mso_rewrite_heap_type(source, []), source)
  }
}

///|
test "make-shared-objects fails closed on string producers" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (global stringref (string.const "global"))
      #|  (func (export "run") (result stringref)
      #|    (string.const "hello")))
      #|),
    ),
  )
  let validation = @validate.validate_module(input)
  assert_true(validation.is_ok(), msg=@debug.to_string(validation))
  assert_eq(make_shared_objects_run_module_pass(input), input)
}

///|
test "make-shared-objects fails closed on string cast boundaries" {
  let input = pass_test_module_from_wat(
    "(module (func (param externref) (result i32) (local.get 0) drop i32.const 0))",
  )
  let funcs = input.code_sec.unwrap().0.copy()
  let @lib.Func(locals, _) = funcs[0]
  let string_heap = @lib.HeapType::abs(@lib.AbsHeapType::string_())
  funcs[0] = @lib.Func::new(
    locals,
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_test_type(@lib.RefType::new(true, string_heap)),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::ref_cast_type(@lib.RefType::new(true, string_heap)),
      @lib.Instruction::drop(),
      @lib.Instruction::i32_const(@lib.I32(0)),
    ]),
  )
  let input = input.with_code_sec(@lib.CodeSec::new(funcs))
  let validation = @validate.validate_module(input)
  assert_true(validation.is_ok(), msg=@debug.to_string(validation))
  assert_eq(make_shared_objects_run_module_pass(input), input)
}

///|
test "make-shared-objects scans and rewrites conversions in EH bodies" {
  let body = @lib.Expr::new([
    @lib.Instruction::try_(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::extern_convert_any()]),
      [
        @lib.LegacyCatch::all(
          @lib.Expr::new([@lib.Instruction::any_convert_extern()]),
        ),
      ],
    ),
    @lib.Instruction::try_table(
      @lib.BlockType::void_(),
      [],
      @lib.Expr::new([@lib.Instruction::extern_convert_any()]),
    ),
  ])
  let needs_any_to_extern = [false]
  let needs_extern_to_any = [false]
  mso_scan_conversions(body, needs_any_to_extern, needs_extern_to_any)
  assert_true(needs_any_to_extern[0])
  assert_true(needs_extern_to_any[0])
  let rewritten = mso_rewrite_conversions(
    body,
    Some(@lib.FuncIdx::new(0U)),
    Some(@lib.FuncIdx::new(1U)),
    @lib.FuncIdx::new(2U),
    @lib.FuncIdx::new(3U),
  )
  assert_eq(
    binaryen133_shared_opcode_count(
      @lib.Module::new().with_code_sec(
        @lib.CodeSec::new([@lib.Func::new(@lib.Locals::empty(), rewritten)]),
      ),
      @lib.Instruction::extern_convert_any(),
    ),
    0,
  )
  let redirected = mso_retarget_import_calls(
    @lib.Expr::new([
      @lib.Instruction::try_(
        @lib.BlockType::void_(),
        @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(0U))]),
        [
          @lib.LegacyCatch::all(
            @lib.Expr::new([
              @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
            ]),
          ),
        ],
      ),
      @lib.Instruction::try_table(
        @lib.BlockType::void_(),
        [],
        @lib.Expr::new([@lib.Instruction::call(@lib.FuncIdx::new(0U))]),
      ),
    ]),
    Map([(0U, 4U)]),
  )
  let redirected_module = @lib.Module::new().with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(@lib.Locals::empty(), redirected)]),
  )
  assert_eq(
    binaryen133_shared_opcode_count(
      redirected_module,
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    ),
    0,
  )
  assert_eq(
    binaryen133_shared_opcode_count(
      redirected_module,
      @lib.Instruction::call(@lib.FuncIdx::new(4U)),
    ),
    2,
  )
  assert_eq(
    binaryen133_shared_opcode_count(
      redirected_module,
      @lib.Instruction::return_call(@lib.FuncIdx::new(4U)),
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
