///|
test "directize rewrites a constant table target to a direct call" {
  let source =
    #|(module
    #|  (type (func (param i32) (result i32)))
    #|  (table 1 funcref)
    #|  (func $target (type 0) (param i32) (result i32)
    #|    local.get 0)
    #|  (elem (i32.const 0) $target)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 0
    #|    call_indirect (type 0)))
  let input = pass_test_module_from_wat(source)
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["directize"]) {
    Ok(mod) => mod
    Err(err) => fail("expected directize pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected directized module to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("(call (Func 0))"), msg=pretty)
  assert_false(pretty.contains("call_indirect"), msg=pretty)
}

///|
test "directize leaves mutable tables indirect" {
  let source =
    #|(module
    #|  (type (func (param i32) (result i32)))
    #|  (table 1 funcref)
    #|  (func $target (type 0) (param i32) (result i32)
    #|    local.get 0)
    #|  (elem (i32.const 0) $target)
    #|  (func (export "run") (param funcref) (param i32) (result i32)
    #|    i32.const 0
    #|    local.get 0
    #|    table.set 0
    #|    local.get 1
    #|    i32.const 0
    #|    call_indirect (type 0)))
  let input = pass_test_module_from_wat(source)
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["directize"]) {
    Ok(mod) => mod
    Err(err) => fail("expected mutable-table directize success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected mutable-table module to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call_indirect"), msg=pretty)
  assert_false(pretty.contains("(call (Func 0))"), msg=pretty)
}

///|
test "directize lowers select of known targets to direct-call branches" {
  let source =
    #|(module
    #|  (type (func (param i32) (result i32)))
    #|  (table 2 funcref)
    #|  (func $a (type 0) (param i32) (result i32) local.get 0)
    #|  (func $b (type 0) (param i32) (result i32) local.get 0 i32.const 1 i32.add)
    #|  (elem (i32.const 0) $a $b)
    #|  (func (export "run") (param i32 i32) (result i32)
    #|    local.get 0
    #|    i32.const 0
    #|    i32.const 1
    #|    local.get 1
    #|    select
    #|    call_indirect (type 0)))
  let input = pass_test_module_from_wat(source)
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["directize"]) {
    Ok(mod) => mod
    Err(err) => fail("expected select directize success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected select-directized module to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("(call (Func 0))"), msg=pretty)
  assert_true(pretty.contains("(call (Func 1))"), msg=pretty)
  assert_false(pretty.contains("call_indirect"), msg=pretty)
}

///|
test "directize discovers long select argument and condition producers in one scan" {
  let depth = 128
  let source = StringBuilder::new()
  source.write_string(
    "(module (type (func (param i32) (result i32))) (table 2 funcref) ",
  )
  source.write_string(
    "(func $a (type 0) (param i32) (result i32) local.get 0) ",
  )
  source.write_string(
    "(func $b (type 0) (param i32) (result i32) local.get 0 i32.const 1 i32.add) ",
  )
  source.write_string("(elem (i32.const 0) $a $b) ")
  source.write_string("(func (param i32 i32) (result i32) local.get 0 ")
  for _ in 0..<depth {
    source.write_string("i32.const 1 i32.add ")
  }
  source.write_string("i32.const 0 i32.const 1 local.get 1 ")
  for _ in 0..<depth {
    source.write_string("i32.const 1 i32.add ")
  }
  source.write_string("select call_indirect (type 0)))")
  let optimized = match
    pass_test_run_pipeline(source.to_string(), ["directize"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected long select directize success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected valid long select directize output, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("if"), msg=pretty)
  assert_false(pretty.contains("call_indirect"), msg=pretty)
}

///|
test "directize preserves producer provenance across rewritten call results" {
  let source =
    #| (module
    #|   (type (func (param i32) (result i32)))
    #|   (table 2 funcref)
    #|   (func $a (type 0) (param i32) (result i32) local.get 0)
    #|   (func $b (type 0) (param i32) (result i32)
    #|     local.get 0 i32.const 1 i32.add)
    #|   (elem (i32.const 0) $a $b)
    #|   (func (param i32 i32) (result i32)
    #|     i32.const 5
    #|     i32.const 0
    #|     i32.const 1
    #|     local.get 0
    #|     select
    #|     call_indirect (type 0)
    #|     i32.const 0
    #|     i32.const 1
    #|     local.get 1
    #|     select
    #|     call_indirect (type 0)))
    #|
  let optimized = match pass_test_run_pipeline(source, ["directize"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected chained select directize success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected valid chained select output, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(pretty.contains("call_indirect"), msg=pretty)
}

///|
test "directize lowers multi-result select of known targets" {
  let source =
    #|(module
    #|  (type (func (result i32 i64)))
    #|  (table 2 funcref)
    #|  (func $a (type 0) (result i32 i64) i32.const 1 i64.const 2)
    #|  (func $b (type 0) (result i32 i64) i32.const 3 i64.const 4)
    #|  (elem (i32.const 0) $a $b)
    #|  (func (export "run") (param i32) (result i32 i64)
    #|    i32.const 0
    #|    i32.const 1
    #|    local.get 0
    #|    select
    #|    call_indirect (type 0)))
  let optimized = match pass_test_run_pipeline(source, ["directize"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected multi-result select directize success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected valid multi-result select output, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("(call (Func 0))"), msg=pretty)
  assert_true(pretty.contains("(call (Func 1))"), msg=pretty)
  assert_false(pretty.contains("call_indirect"), msg=pretty)
}

///|
test "directize reuses one block signature for repeated parameterized multivalue selects" {
  let source =
    #|(module
    #|  (type (func (param i32) (result i32 i64)))
    #|  (table 2 funcref)
    #|  (func $a (type 0) (param i32) (result i32 i64)
    #|    local.get 0 i64.const 2)
    #|  (func $b (type 0) (param i32) (result i32 i64)
    #|    local.get 0 i64.const 4)
    #|  (elem (i32.const 0) $a $b)
    #|  (func (export "run") (param i32 i32)
    #|    local.get 0
    #|    i32.const 0
    #|    i32.const 1
    #|    local.get 1
    #|    select
    #|    call_indirect (type 0)
    #|    drop
    #|    drop
    #|    local.get 0
    #|    i32.const 0
    #|    i32.const 1
    #|    local.get 1
    #|    select
    #|    call_indirect (type 0)
    #|    drop
    #|    drop))
  let input = pass_test_module_from_wat(source)
  let before_count = match input.type_sec {
    Some(@lib.TypeSec(rec_types)) => rec_types.length()
    None => 0
  }
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["directize"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected repeated multivalue directize success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected valid repeated multivalue output, got \{err}")
  }
  let after_count = match optimized.type_sec {
    Some(@lib.TypeSec(rec_types)) => rec_types.length()
    None => 0
  }
  assert_eq(after_count, before_count + 1)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(pretty.contains("call_indirect"), msg=pretty)
}

///|
test "directize lowers return-call select of known targets" {
  let source =
    #|(module
    #|  (type (func (param i32) (result i32)))
    #|  (table 2 funcref)
    #|  (func $a (type 0) (param i32) (result i32) local.get 0)
    #|  (func $b (type 0) (param i32) (result i32) local.get 0 i32.const 1 i32.add)
    #|  (elem (i32.const 0) $a $b)
    #|  (func (export "run") (param i32 i32) (result i32)
    #|    local.get 0
    #|    i32.const 0
    #|    i32.const 1
    #|    local.get 1
    #|    select
    #|    return_call_indirect (type 0)))
  let input = pass_test_module_from_wat(source)
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["directize"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected return-call select directize success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected return-call select-directized module to validate, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("return_call_indirect"), msg=pretty)
}

///|
fn directize_v131_ref_func_initializer_fixture(
  grow? : Bool = false,
  call_offset? : Int = 0,
) -> @lib.Module {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let table_type = @lib.TableType::new(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::func())),
    @lib.Limits::i32(1U, None),
  )
  let caller_body : Array[@lib.Instruction] = []
  if grow {
    caller_body.push(
      @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::func())),
    )
    caller_body.push(@lib.Instruction::i32_const(@lib.I32(1)))
    caller_body.push(@lib.Instruction::table_grow(@lib.TableIdx::new(0U)))
    caller_body.push(@lib.Instruction::drop())
  }
  caller_body.push(@lib.Instruction::i32_const(@lib.I32(call_offset)))
  caller_body.push(
    @lib.Instruction::call_indirect(
      @lib.TypeIdx::new(0U),
      @lib.TableIdx::new(0U),
    ),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([func_type]))
  .with_func_sec(
    @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(0U)]),
  )
  .with_table_sec(
    @lib.TableSec::new([
      @lib.Table::new(
        table_type,
        Some(
          @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(1U))]),
        ),
      ),
    ]),
  )
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("run"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(caller_body)),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(42))]),
      ),
    ]),
  )
}

///|
test "directize v131 uses ref.func table initializers" {
  let optimized = match
    run_hot_pipeline(
      directize_v131_ref_func_initializer_fixture(),
      HotPipelineOptions::new(),
      ["directize"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected initializer directize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(call (Func 1))"), msg=pretty)
  assert_false(pretty.contains("call_indirect"), msg=pretty)
}

///|
test "directize v131 reads initializer entries below table growth" {
  let optimized = match
    run_hot_pipeline(
      directize_v131_ref_func_initializer_fixture(grow=true),
      HotPipelineOptions::new(),
      ["directize"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected grown initializer directize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("(call (Func 1))"), msg=pretty)
  assert_false(pretty.contains("call_indirect"), msg=pretty)
}

///|
test "directize v131 leaves grown out-of-range entries unknown" {
  let optimized = match
    run_hot_pipeline(
      directize_v131_ref_func_initializer_fixture(grow=true, call_offset=1),
      HotPipelineOptions::new(),
      ["directize"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected grown unknown directize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("call_indirect"), msg=pretty)
  assert_false(pretty.contains("unreachable"), msg=pretty)
}

///|
test "directize leaves explicit ref.null table defaults unknown like Binaryen" {
  let funcref = @lib.RefType::new(
    true,
    @lib.HeapType::abs(@lib.AbsHeapType::func()),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(funcref, @lib.Limits::i32(1U, Some(1U))),
          Some(
            @lib.Expr::new([
              @lib.Instruction::ref_null(
                @lib.HeapType::abs(@lib.AbsHeapType::func()),
              ),
            ]),
          ),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::call_indirect(
              @lib.TypeIdx::new(0U),
              @lib.TableIdx::new(0U),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["directize"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected explicit-null directize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("call_indirect"), msg=pretty)
  assert_false(pretty.contains("unreachable"), msg=pretty)
}

///|
test "directize rewrites known holes to unreachable" {
  let source =
    #|(module
    #|  (type (func (param i32) (result i32)))
    #|  (table 2 funcref)
    #|  (func $target (type 0) (param i32) (result i32)
    #|    local.get 0)
    #|  (elem (i32.const 1) $target)
    #|  (func (export "run") (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 0
    #|    call_indirect (type 0)))
  let input = pass_test_module_from_wat(source)
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["directize"]) {
    Ok(mod) => mod
    Err(err) => fail("expected known-hole directize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("call_indirect"), msg=pretty)
}

///|
test "directize sees table mutations inside legacy try regions" {
  let source =
    #|(module
    #|  (type (func (param i32) (result i32)))
    #|  (tag $e)
    #|  (table 1 funcref)
    #|  (func $target (type 0) (param i32) (result i32) local.get 0)
    #|  (elem (i32.const 0) $target)
    #|  (func (export "run") (param funcref i32) (result i32)
    #|    (try
    #|      (do
    #|        i32.const 0
    #|        local.get 0
    #|        table.set 0)
    #|      (catch $e))
    #|    local.get 1
    #|    i32.const 0
    #|    call_indirect (type 0)))
  let optimized = match pass_test_run_pipeline(source, ["directize"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected legacy mutation directize success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected valid legacy mutation output, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("table.set"), msg=pretty)
  assert_true(pretty.contains("call_indirect"), msg=pretty)
}

///|
test "directize rewrites eligible indirect calls inside legacy try catches" {
  let source =
    #|(module
    #|  (type (func (param i32) (result i32)))
    #|  (tag $e)
    #|  (table 1 funcref)
    #|  (func $target (type 0) (param i32) (result i32) local.get 0)
    #|  (elem (i32.const 0) $target)
    #|  (func (export "run") (param i32) (result i32)
    #|    (try (result i32)
    #|      (do
    #|        unreachable)
    #|      (catch $e
    #|        local.get 0
    #|        i32.const 0
    #|        call_indirect (type 0)))))
  let optimized = match pass_test_run_pipeline(source, ["directize"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected legacy catch directize success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected valid legacy catch output, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("(call (Func 0))"), msg=pretty)
  assert_false(pretty.contains("call_indirect"), msg=pretty)
}

///|
test "directize lowers a known-target and known-trap select" {
  let source =
    #|(module
    #|  (type (func (param i32) (result i32)))
    #|  (table 2 2 funcref)
    #|  (func $target (type 0) (param i32) (result i32) local.get 0)
    #|  (elem (i32.const 1) $target)
    #|  (func (export "run") (param i32 i32) (result i32)
    #|    local.get 0
    #|    i32.const 0
    #|    i32.const 1
    #|    local.get 1
    #|    select
    #|    call_indirect (type 0)))
  let optimized = match pass_test_run_pipeline(source, ["directize"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected select trap directize success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected valid select trap output, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_true(pretty.contains("(call (Func 0))"), msg=pretty)
  assert_false(pretty.contains("call_indirect"), msg=pretty)
}

///|
fn directize_table64_fixture() -> @lib.Module {
  let type_idx = @lib.TypeIdx::new(0U)
  let funcref = @lib.RefType::new(
    true,
    @lib.HeapType::abs(@lib.AbsHeapType::func()),
  )
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
        ),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([type_idx, type_idx, type_idx]))
  .with_table_sec(
    @lib.TableSec::new([
      @lib.Table::new(
        @lib.TableType::new(funcref, @lib.Limits::i64(2UL, Some(2UL))),
        None,
      ),
    ]),
  )
  .with_elem_sec(
    @lib.ElemSec::new([
      @lib.Elem::new(
        @lib.ElemMode::active(
          @lib.TableIdx::new(0U),
          @lib.Expr::new([@lib.Instruction::i64_const(@lib.I64(1L))]),
        ),
        @lib.ElemKind::typed_exprs(funcref, [
          @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(0U))]),
        ]),
      ),
    ]),
  )
  .with_export_sec(
    @lib.ExportSec::new([
      @lib.Export::new(
        @lib.Name::from_string("known"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(1U)),
      ),
      @lib.Export::new(
        @lib.Name::from_string("wide"),
        @lib.ExternIdx::func(@lib.FuncIdx::new(2U)),
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i64_const(@lib.I64(1L)),
          @lib.Instruction::call_indirect(type_idx, @lib.TableIdx::new(0U)),
        ]),
      ),
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::i64_const(@lib.I64(4294967297L)),
          @lib.Instruction::call_indirect(type_idx, @lib.TableIdx::new(0U)),
        ]),
      ),
    ]),
  )
}

///|
test "directize handles table64 targets without truncation" {
  let optimized = match
    run_hot_pipeline(directize_table64_fixture(), HotPipelineOptions::new(), [
      "directize",
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected table64 directize success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected valid table64 output, got \{err}")
  }
  let known = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(known.contains("(call (Func 0))"), msg=known)
  assert_false(known.contains("call_indirect"), msg=known)
  let wide = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(wide.contains("unreachable"), msg=wide)
  assert_false(wide.contains("(call (Func 0))"), msg=wide)
  assert_false(wide.contains("call_indirect"), msg=wide)
}

///|
test "directize GenValid leaves all exercise pass-owned rewrites" {
  let profile_names = [
    "directize-constant", "directize-select", "directize-table-facts", "directize-tail-call",
    "directize-gc", "directize-table64", "directize-legacy-eh", "directize-boundaries",
  ]
  let profiles : Array[@validate.GenValidProfile] = []
  for name in profile_names {
    match @validate.gen_valid_profile_by_name(name) {
      Ok(profile) => profiles.push(profile)
      Err(msg) => fail(msg)
    }
  }
  for profile_index = 0
      profile_index < profiles.length()
      profile_index = profile_index + 1 {
    for variant = 0; variant < 5; variant = variant + 1 {
      let seed = 0x44495200UL +
        profile_index.to_uint64() * 16UL +
        variant.to_uint64()
      let generated = match
        @validate.gen_valid_module_result_from_seed(
          seed,
          @validate.GenValidConfig::for_profile(profiles[profile_index]),
        ) {
        Ok(value) => value
        Err(failure) => fail(failure.validation_error_message)
      }
      let optimized = match
        run_hot_pipeline(generated.wasm_module, HotPipelineOptions::new(), [
          "directize",
        ]) {
        Ok(mod_) => mod_
        Err(err) => fail("expected generated directize success, got \{err}")
      }
      match @validate.validate_module(optimized) {
        Ok(_) => ()
        Err(err) =>
          fail("expected valid generated directize output, got \{err}")
      }
      assert_true(
        optimized != generated.wasm_module,
        msg="profile \{@validate.gen_valid_profile_name(profiles[profile_index])} seed \{seed} did not trigger directize",
      )
    }
  }
}
