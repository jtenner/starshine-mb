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
