///|
fn branchless_cleanup_gate_reference(
  func : @lib.Func,
  mod_ : @lib.Module,
  module_env~ : @validate.Env? = None,
  flatten_parameter_blocks~ : Bool = false,
  flatten_scalar_identity_blocks~ : Bool = false,
) -> (@lib.Func, Bool) {
  let @lib.Func(locals, @lib.Expr(body)) = func
  let env = match module_env {
    Some(env) => env
    None => @validate.Env::new().with_module(mod_)
  }
  let (body, changed, _) = pass_lower_flatten_branchless_blocks(
    body,
    env,
    flatten_parameter_blocks~,
    flatten_scalar_identity_blocks~,
  )
  if changed {
    (@lib.Func::new(locals, @lib.Expr::new(body)), true)
  } else {
    (func, false)
  }
}

///|
test "branchless cleanup retains candidate-free control bodies without rewrite work" {
  for
    source in [
      "(module (memory 1) (func (export \"run\") (param i32) (result i32) loop local.get 0 if i32.const 0 i32.load drop else local.get 0 drop end end local.get 0))",
      "(module (func (export \"run\") (result i32) block i32.const 7 return end i32.const 8))",
    ] {
    let input = pass_test_module_from_wat(source)
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let func = input.code_sec.unwrap().0[0]
    let expected = branchless_cleanup_gate_reference(func, input)
    let work = [0]
    let (output, changed) = pass_lower_cleanup_branchless_blocks(
      func,
      input,
      rewrite_work=Some(work),
    )
    assert_false(changed)
    assert_eq(output, expected.0)
    assert_true(physical_equal(output, func))
    let @lib.Func(_, @lib.Expr(before)) = func
    let @lib.Func(_, @lib.Expr(after)) = output
    assert_true(physical_equal(after, before))
    let selected = input.with_code_sec(@lib.CodeSec::new([output]))
    @validate.validate_module(selected).unwrap()
    assert_true(physical_equal(selected.name_sec, input.name_sec))
    assert_eq(@binary.encode_module(selected).unwrap(), saved)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    assert_eq(work[0], 0)
  }
}

///|
test "branchless cleanup keeps nested candidates below controls and preserves label preorder" {
  let input = pass_test_module_from_wat(
    "(module (func (export \"run\") (param i32) (result i32) block local.get 0 if block i32.const 7 return end else loop block nop end end end end i32.const 8))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let func = input.code_sec.unwrap().0[0]
  let expected = branchless_cleanup_gate_reference(func, input)
  let work = [0]
  let (output, changed) = pass_lower_cleanup_branchless_blocks(
    func,
    input,
    rewrite_work=Some(work),
  )
  assert_true(changed)
  assert_eq(output, expected.0)
  assert_eq(work[0], 1)
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([output]))).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = func
  let labels = []
  ignore(
    pass_lower_flatten_branchless_blocks(
      body,
      @validate.Env::new().with_module(input),
      label_keep=Some(labels),
    ),
  )
  assert_eq(labels, [true, true, true, true, false])
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "branchless summary stops after a nested candidate before cold siblings and another arm" {
  let cold = Array::make(128, "local.get 0 drop").join(" ")
  let input = pass_test_module_from_wat(
    "(module (func (export \"run\") (param i32) (result i32) local.get 0 if block nop end \{cold} else \{cold} end local.get 0))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let func = input.code_sec.unwrap().0[0]
  let @lib.Func(_, @lib.Expr(body)) = func
  let visits = [0]
  let summary = pass_lower_branchless_summary(body, visits=Some(visits))
  assert_true(summary.has_candidate)
  let reference = branchless_cleanup_gate_reference(func, input)
  let actual = pass_lower_cleanup_branchless_blocks(func, input)
  assert_eq(actual, reference)
  assert_true(actual.1)
  let output = input.with_code_sec(@lib.CodeSec::new([actual.0]))
  @validate.validate_module(output).unwrap()
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(input.with_code_sec(@lib.CodeSec::new([reference.0]))).unwrap(),
  )
  assert_true(physical_equal(output.name_sec, input.name_sec))
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  let labels = []
  ignore(
    pass_lower_flatten_branchless_blocks(
      body,
      @validate.Env::new().with_module(input),
      label_keep=Some(labels),
    ),
  )
  assert_eq(labels, [true, false])
  // Classify the outer get and if, the first arm's Block, and its Nop.
  // The remaining arm, sibling leaves, and outer result do not affect admission.
  assert_eq(visits[0], 4)
}

///|
test "branchless summary retains every transfer opcode classification" {
  let label = @lib.LabelIdx::new(0U)
  let type_ = @lib.TypeIdx::new(0U)
  let heap = @lib.HeapType::new(type_)
  let ref_ = @lib.RefType::new(true, heap)
  let tag = @lib.TagIdx::new(0U)
  // Instruction fragments test the worker's classification, not validation of
  // their surrounding stack, label, feature or continuation contexts.
  for
    instr in [
      @lib.Instruction::br(label),
      @lib.Instruction::br_if(label),
      @lib.Instruction::br_table([label], label),
      @lib.Instruction::br_on_null(label),
      @lib.Instruction::br_on_non_null(label),
      @lib.Instruction::br_on_cast(label, true, heap, false, heap),
      @lib.Instruction::br_on_cast_fail(label, true, heap, false, heap),
      @lib.Instruction::br_on_cast_desc_eq(label, ref_, ref_),
      @lib.Instruction::br_on_cast_desc_eq_fail(label, ref_, ref_),
      @lib.Instruction::return_(),
      @lib.Instruction::return_call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::return_call_indirect(type_, @lib.TableIdx::new(0U)),
      @lib.Instruction::return_call_ref(type_),
      @lib.Instruction::unreachable_(),
      @lib.Instruction::try_(@lib.BlockType::void_(), @lib.Expr::new([]), []),
      @lib.Instruction::try_table(
        @lib.BlockType::void_(),
        [],
        @lib.Expr::new([]),
      ),
      @lib.Instruction::throw_(tag),
      @lib.Instruction::throw_ref(),
      @lib.Instruction::rethrow(label),
      @lib.Instruction::suspend(tag),
      @lib.Instruction::resume_(type_, []),
      @lib.Instruction::resume_throw(type_, tag, []),
      @lib.Instruction::resume_throw_ref(type_, []),
      @lib.Instruction::stack_switch(type_, tag),
    ] {
    let summary = pass_lower_branchless_summary([instr])
    assert_false(summary.branchless)
    assert_false(summary.has_candidate)
    let (_, changed, branchless) = pass_lower_flatten_branchless_blocks(
      [instr],
      @validate.Env::new(),
    )
    assert_false(changed)
    assert_false(branchless)
  }
}

///|
test "branchless summary keeps candidates inside exception bodies and handlers" {
  let input = pass_test_module_from_wat("(module (func))")
  let block = @lib.Instruction::block(
    @lib.BlockType::void_(),
    @lib.Expr::new([@lib.Instruction::nop()]),
  )
  let body = [
    @lib.Instruction::try_(@lib.BlockType::void_(), @lib.Expr::new([block]), [
      @lib.LegacyCatch::all(@lib.Expr::new([block])),
    ]),
    @lib.Instruction::try_table(
      @lib.BlockType::void_(),
      [],
      @lib.Expr::new([block]),
    ),
  ]
  let func = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body))
  let input = input.with_code_sec(@lib.CodeSec::new([func]))
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let summary = pass_lower_branchless_summary(body)
  assert_true(summary.has_candidate)
  assert_false(summary.branchless)
  let expected = branchless_cleanup_gate_reference(func, input)
  let (output, changed) = pass_lower_cleanup_branchless_blocks(func, input)
  assert_true(changed)
  assert_eq(output, expected.0)
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([output]))).unwrap()
  let labels = []
  ignore(
    pass_lower_flatten_branchless_blocks(
      body,
      @validate.Env::new().with_module(input),
      label_keep=Some(labels),
    ),
  )
  assert_eq(labels, [true, false, false, true, false])
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "branchless gate leaves invalid block header decisions with the existing worker" {
  let input = pass_test_module_from_wat("(module (func))")
  let func = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::type_idx(@lib.TypeIdx::new(99U)),
        @lib.Expr::new([@lib.Instruction::nop()]),
      ),
    ]),
  )
  let input = input.with_code_sec(@lib.CodeSec::new([func]))
  // This header is deliberately invalid. The gate must still admit the old
  // signature expansion path rather than assume that a candidate can flatten.
  let expected = branchless_cleanup_gate_reference(func, input)
  let work = [0]
  let (output, changed) = pass_lower_cleanup_branchless_blocks(
    func,
    input,
    rewrite_work=Some(work),
  )
  assert_false(changed)
  assert_eq(output, expected.0)
  assert_eq(work[0], 1)
  assert_true(@validate.validate_module(input) is Err(_))
  assert_eq(
    @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([output]))),
    @validate.validate_module(input),
  )
}
