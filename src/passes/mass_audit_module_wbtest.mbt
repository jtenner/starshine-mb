///|
// The parent runs these tests after all eight audit agents finish.
fn mass_audit_module_dae_legacy_fixture(mode : Int) -> @lib.Module {
  let input = pass_test_module_from_wat(
    "(module (tag) (func $f (param i32) (result i32) (local i32) i32.const 0) (func (export \"run\") (result i32) i32.const 5 call $f))",
  )
  let get = @lib.Instruction::local_get(@lib.LocalIdx::new(0U))
  let set = @lib.Instruction::local_set(@lib.LocalIdx::new(0U))
  let (block_type, body, handler) = match mode {
    0 =>
      (
        @lib.BlockType::void_(),
        [
          get,
          @lib.Instruction::i32_const(@lib.I32(1)),
          @lib.Instruction::i32_add(),
          set,
        ],
        [@lib.Instruction::nop()],
      )
    1 =>
      (
        @lib.BlockType::void_(),
        [@lib.Instruction::throw_(@lib.TagIdx::new(0U))],
        [@lib.Instruction::i32_const(@lib.I32(6)), set],
      )
    _ => (@lib.BlockType::val_type(@lib.ValType::i32()), [get], [get])
  }
  let body = [
    @lib.Instruction::try_(block_type, @lib.Expr::new(body), [
      @lib.LegacyCatch::all(@lib.Expr::new(handler)),
    ]),
  ]
  if mode < 2 {
    body.push(get)
  }
  let funcs = input.code_sec.unwrap().0.copy()
  funcs[0] = @lib.Func::new(
    @lib.Locals::from_types([@lib.ValType::i32()]),
    @lib.Expr::new(body),
  )
  let result = input.with_code_sec(@lib.CodeSec::new(funcs))
  @validate.validate_module(result).unwrap()
  result
}

///|
test "mass audit module DAE local-use scans legacy body writes" {
  let input = mass_audit_module_dae_legacy_fixture(0)
  let use_ = dae_local_use_for_callee(input.code_sec.unwrap().0[0], 2, 0, 1)
  assert_true(use_.gets[0])
  assert_true(use_.writes[0])
}

///|
test "mass audit module DAE local-use scans legacy catch writes" {
  let input = mass_audit_module_dae_legacy_fixture(1)
  let use_ = dae_local_use_for_callee(input.code_sec.unwrap().0[0], 2, 0, 1)
  assert_true(use_.gets[0])
  assert_true(use_.writes[0])
}

///|
test "mass audit module DAE local-use scans legacy-only reads" {
  let input = mass_audit_module_dae_legacy_fixture(2)
  let use_ = dae_local_use_for_callee(input.code_sec.unwrap().0[0], 2, 0, 1)
  assert_true(use_.gets[0])
  assert_false(use_.writes[0])
}

///|
test "mass audit module DAE constant substitution visits legacy body and catch" {
  let input = mass_audit_module_dae_legacy_fixture(2)
  let constant = @lib.Instruction::i32_const(@lib.I32(5))
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let rewritten = dae_rewrite_param_const_instrs(body, [Some(constant)])
  assert_eq(rewritten, [
    @lib.Instruction::try_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([constant]),
      [@lib.LegacyCatch::all(@lib.Expr::new([constant]))],
    ),
  ])
}

///|
test "mass audit module plain DAE preserves a parameter written in legacy control" {
  for mode in 0..<2 {
    let input = mass_audit_module_dae_legacy_fixture(mode)
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "dead-argument-elimination",
    ]).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    // The original and verified Binaryen 133 return 6. A literal 5 is the
    // stale input value, even when the resulting module still validates.
    assert_true(body.last() is Some(@lib.LocalGet(_)))
  }
}

///|
test "mass audit module optimizing DAE retains the changed legacy parameter value" {
  for mode in 0..<2 {
    let input = mass_audit_module_dae_legacy_fixture(mode)
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "dae-optimizing",
    ]).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
    // Verified Binaryen 133 folds both fixtures to the value after the write.
    assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(6))])
  }
}

///|
test "mass audit module optimizing DAE replaces legacy-only constant parameter reads" {
  let input = mass_audit_module_dae_legacy_fixture(2)
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "dae-optimizing",
  ]).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(5))])
}

///|
fn mass_audit_module_dae_table_initializer_fixture() -> @lib.Module {
  let input = pass_test_module_from_wat(
    "(module (type $main (func (result i32))) (type $init (func (param i32))) (table 1 funcref) (func (export \"run\") (type $main) table.size 0))",
  )
  let result = input.with_table_sec(
    @lib.TableSec::new([
      @lib.Table::new(
        @lib.TableType::new(
          @lib.RefType::abs(@lib.AbsHeapType::func()),
          @lib.Limits::i32(1U, None),
        ),
        Some(
          @lib.Expr::new([
            @lib.Instruction::ref_null(
              @lib.HeapType::new(@lib.TypeIdx::new(1U)),
            ),
          ]),
        ),
      ),
    ]),
  )
  @validate.validate_module(result).unwrap()
  result
}

///|
test "mass audit module DAE type pruning keeps a table initializer type root" {
  let input = mass_audit_module_dae_table_initializer_fixture()
  let output = dae_prune_unused_simple_func_types(input)
  @validate.validate_module(output).unwrap()
  assert_eq(output.type_sec.unwrap().0.length(), 2)
  assert_eq(output.table_sec, input.table_sec)
}

///|
test "mass audit module DAE dispatcher keeps a valid table initializer" {
  for pass in ["dead-argument-elimination", "dae-optimizing"] {
    let output = run_hot_pipeline(
      mass_audit_module_dae_table_initializer_fixture(),
      HotPipelineOptions::new(),
      [pass],
    ).unwrap()
    @validate.validate_module(output).unwrap()
  }
}

///|
fn mass_audit_module_dae_legacy_caller_fixture(in_catch : Bool) -> @lib.Module {
  let input = pass_test_module_from_wat(
    "(module (tag) (func $f (param i32) nop) (func (export \"run\") nop))",
  )
  let call = [
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ]
  let (body, handler) = if in_catch {
    ([@lib.Instruction::throw_(@lib.TagIdx::new(0U))], call)
  } else {
    (call, [@lib.Instruction::nop()])
  }
  let funcs = input.code_sec.unwrap().0.copy()
  funcs[1] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::try_(@lib.BlockType::void_(), @lib.Expr::new(body), [
        @lib.LegacyCatch::all(@lib.Expr::new(handler)),
      ]),
    ]),
  )
  let result = input.with_code_sec(@lib.CodeSec::new(funcs))
  @validate.validate_module(result).unwrap()
  result
}

///|
test "mass audit module DAE removes a dead argument inside legacy try and catch" {
  for in_catch in [false, true] {
    for pass in ["dead-argument-elimination", "dae-optimizing"] {
      let output = run_hot_pipeline(
        mass_audit_module_dae_legacy_caller_fixture(in_catch),
        HotPipelineOptions::new(),
        [pass],
      ).unwrap()
      @validate.validate_module(output).unwrap()
      let @lib.FuncType(params, _) = @validate.Env::new()
        .with_module(output)
        .get_functype_by_funcidx(@lib.FuncIdx::new(0U))
        .unwrap()
      assert_eq(params.length(), 0)
    }
  }
}

///|
test "mass audit module module passes optimize ordinary siblings of legacy control" {
  let input = pass_test_module_from_wat(
    "(module (func $a (result i32) i32.const 3) (func $b (result i32) i32.const 3) (func (result i32) i32.const 4) (func (export \"run\") (result i32) call $a call $b i32.add))",
  )
  let funcs = input.code_sec.unwrap().0.copy()
  let four = @lib.Instruction::i32_const(@lib.I32(4))
  funcs[2] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::try_(
        @lib.BlockType::val_type(@lib.ValType::i32()),
        @lib.Expr::new([four]),
        [@lib.LegacyCatch::all(@lib.Expr::new([four]))],
      ),
    ]),
  )
  let input = input.with_code_sec(@lib.CodeSec::new(funcs))
  @validate.validate_module(input).unwrap()
  for
    pass in [
      "duplicate-function-elimination", "inlining", "inlining-optimizing",
    ] {
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [pass]).unwrap()
    @validate.validate_module(output).unwrap()
    // This requires a real ordinary-function transform, not guard removal.
    // Verified v133 merges the duplicate pair or deletes both inlined helpers.
    let count_limit = if pass == "duplicate-function-elimination" {
      3
    } else {
      2
    }
    assert_true(output.code_sec.unwrap().0.length() <= count_limit)
  }
}

///|
test "mass audit module inlining size arithmetic keeps large ceilings monotonic" {
  assert_true(
    inl_combined_binary_size_within_limit(
      1,
      1,
      max_combined_binary_size=0x7fffffff,
    ),
  )
  // These are arithmetic boundaries only. No large module is allocated.
  assert_false(inl_combined_binary_size_within_limit(500000000, 0))
  assert_false(inl_combined_binary_size_within_limit(0x40000000, 0x40000000))
}

///|
test "mass audit module large inlining ceiling still removes a tiny helper" {
  let input = pass_test_module_from_wat(
    "(module (func $f (result i32) i32.const 7) (func (export \"run\") (result i32) call $f))",
  )
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(inlining_max_combined_binary_size=0x7fffffff),
    ["inlining"],
  ).unwrap()
  @validate.validate_module(output).unwrap()
  let funcs = output.code_sec.unwrap().0
  assert_eq(funcs.length(), 1)
  let @lib.Func(_, @lib.Expr(body)) = funcs[0]
  assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(7))])
}
