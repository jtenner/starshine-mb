///|
// Independent, bounded execution of the integer instructions used below.
fn mass_audit_values_run(
  func : @lib.Func,
  args : Array[Int64],
) -> Array[Int64] raise {
  let @lib.Func(body_locals, @lib.Expr(body)) = func
  let locals = args.copy()
  for _ in 0..<body_locals.length() {
    locals.push(0L)
  }
  let stack : Array[Int64] = []
  let mut steps = 0
  fn execute(body : Array[@lib.Instruction]) -> Unit raise {
    for instr in body {
      steps += 1
      if steps > 10000 {
        fail("value fixture execution budget exceeded")
      }
      match instr {
        @lib.Nop => ()
        @lib.I32Const(@lib.I32(value)) => stack.push(value.to_int64())
        @lib.LocalGet(@lib.LocalIdx(index)) =>
          stack.push(locals[index.to_int()])
        @lib.LocalSet(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack.pop().unwrap()
        @lib.LocalTee(@lib.LocalIdx(index)) =>
          locals[index.to_int()] = stack[stack.length() - 1]
        @lib.Drop => ignore(stack.pop().unwrap())
        @lib.I32Add => {
          let rhs = stack.pop().unwrap().to_int()
          let lhs = stack.pop().unwrap().to_int()
          stack.push((lhs + rhs).to_int64())
        }
        @lib.If(bt, yes, no) => {
          let selected = if stack.pop().unwrap() != 0L {
            yes
          } else {
            no.unwrap_or([])
          }
          let base = stack.length()
          execute(selected)
          let arity = match bt {
            @lib.VoidBlockType => 0
            @lib.ValTypeBlockType(_) => 1
            _ => fail("value fixture requires a direct block type")
          }
          if stack.length() != base + arity {
            fail("invalid value fixture stack height")
          }
        }
        _ => fail("unsupported value fixture instruction: \{instr}")
      }
    }
  }
  execute(body)
  stack
}

///|
fn mass_audit_values_count(
  body : Array[@lib.Instruction],
  predicate : (@lib.Instruction) -> Bool,
) -> Int {
  let mut count = 0
  for instr in body {
    if predicate(instr) {
      count += 1
    }
    match instr {
      @lib.Block(_, @lib.Expr(nested))
      | @lib.Loop(_, @lib.Expr(nested))
      | @lib.TryTable(_, _, @lib.Expr(nested)) =>
        count += mass_audit_values_count(nested, predicate)
      @lib.If(_, yes, no) => {
        count += mass_audit_values_count(yes, predicate)
        count += mass_audit_values_count(no.unwrap_or([]), predicate)
      }
      @lib.Try(_, @lib.Expr(nested), catches, _) => {
        count += mass_audit_values_count(nested, predicate)
        for catch_ in catches {
          let body = match catch_ {
            @lib.LegacyCatch(_, @lib.Expr(body))
            | @lib.LegacyCatchAll(@lib.Expr(body)) => body
          }
          count += mass_audit_values_count(body, predicate)
        }
      }
      _ => ()
    }
  }
  count
}

///|
// The parent runs these bounded tests after all eight audit agents finish.
test "mass value audit precompute keeps a scratch write before later reads" {
  for final_write in ["local.set 0", "local.tee 0 drop"] {
    let input = pass_test_module_from_wat(
      "(module (func (param i32) (result i32) (local i32) i32.const 7 local.set 1 local.get 0 local.get 1 i32.add \{final_write} local.get 1))",
    )
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "precompute",
    ]).unwrap()
    @validate.validate_module(output).unwrap()
    let rewritten = output.code_sec.unwrap().0[0]
    for argument in [-4L, 0L, 9L] {
      assert_eq(mass_audit_values_run(rewritten, [argument]), [7L])
    }
  }
}

///|
test "mass value audit raw precompute keeps scratch writes across additive folding" {
  let original = @lib.Func::new(
    @lib.Locals::from_types([@lib.ValType::i32()]),
    @lib.Expr::new([
      @lib.Instruction::i32_const(@lib.I32(7)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::i32_add(),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    ]),
  )
  let @lib.Func(locals, @lib.Expr(body)) = original
  let (rewritten, _) = precompute_raw_rewrite_instrs(body, None)
  let output = @lib.Func::new(locals, @lib.Expr::new(rewritten))
  assert_eq(mass_audit_values_run(output, [3L]), [7L])
}

///|
test "mass value audit unsigned truncation folds negative fractions to zero" {
  let cases : Array[(@lib.Instruction, @lib.Instruction, @lib.Instruction)] = [
    (
      @lib.Instruction::f32_const(@lib.F32(Float::from_double(-0.5))),
      @lib.Instruction::i32_trunc_f32u(),
      @lib.Instruction::i32_const(@lib.I32(0)),
    ),
    (
      @lib.Instruction::f64_const(@lib.F64(-0.9999999999999999)),
      @lib.Instruction::i32_trunc_f64u(),
      @lib.Instruction::i32_const(@lib.I32(0)),
    ),
    (
      @lib.Instruction::f32_const(@lib.F32(Float::from_double(-0.5))),
      @lib.Instruction::i64_trunc_f32u(),
      @lib.Instruction::i64_const(@lib.I64(0L)),
    ),
    (
      @lib.Instruction::f64_const(@lib.F64(-0.5)),
      @lib.Instruction::i64_trunc_f64u(),
      @lib.Instruction::i64_const(@lib.I64(0L)),
    ),
  ]
  for (operand, opcode, expected) in cases {
    assert_eq(precompute_raw_try_fold_unary(operand, opcode), Some(expected))
  }
}

///|
test "mass value audit signed i32 truncation folds the lower fractional boundary" {
  assert_eq(
    precompute_raw_try_fold_unary(
      @lib.Instruction::f64_const(@lib.F64(-2147483648.5)),
      @lib.Instruction::i32_trunc_f64s(),
    ),
    Some(@lib.Instruction::i32_const(@lib.I32(-2147483648))),
  )
}

///|
test "mass value audit public precompute folds valid fractional truncation boundaries" {
  let cases : Array[(String, @lib.Instruction)] = [
    (
      "(module (func (result i32) f32.const -0.5 i32.trunc_f32_u))",
      @lib.Instruction::i32_const(@lib.I32(0)),
    ),
    (
      "(module (func (result i32) f64.const -0.9999999999999999 i32.trunc_f64_u))",
      @lib.Instruction::i32_const(@lib.I32(0)),
    ),
    (
      "(module (func (result i64) f32.const -0.5 i64.trunc_f32_u))",
      @lib.Instruction::i64_const(@lib.I64(0L)),
    ),
    (
      "(module (func (result i64) f64.const -0.5 i64.trunc_f64_u))",
      @lib.Instruction::i64_const(@lib.I64(0L)),
    ),
    (
      "(module (func (result i32) f64.const -2147483648.5 i32.trunc_f64_s))",
      @lib.Instruction::i32_const(@lib.I32(-2147483648)),
    ),
  ]
  for (wat, expected) in cases {
    for name in ["precompute", "precompute-propagate"] {
      let input = pass_test_module_from_wat(wat)
      let output = run_hot_pipeline(input, HotPipelineOptions::new(), [name]).unwrap()
      let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
      assert_eq(body, [expected], msg=name)
      @validate.validate_module(output).unwrap()
    }
  }
}

///|
test "mass value audit condition facts stop after a nested conditional write" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(param_count=1, params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let condition_local = 0
  let written_local = 1
  let nested = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, condition_local),
    [
      @ir.hot_build_local_set(
        func,
        written_local,
        @ir.hot_build_const_i32(func, @lib.I32(9)),
      ),
    ],
  )
  let final_read = @ir.hot_build_local_get(func, written_local)
  let outer = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_local_tee(
      func,
      written_local,
      @ir.hot_build_const_i32(func, @lib.I32(7)),
    ),
    [nested, final_read],
    else_body=Some([@ir.hot_build_const_i32(func, @lib.I32(0))]),
  )
  @ir.hot_root_append(func, outer)
  let ctx = HotPassContext::new(
    precompute_propagate_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  let get_consts : Array[@ir.HotConstPayload?] = Array::make(
    @ir.hot_node_count(func),
    None,
  )
  precompute_propagate_mark_result_if_direct_const_gets(
    ctx, func, outer, get_consts,
  )
  // The inner branch can change this local from 7 to 9. A lexical condition
  // constant must not replace the final read without a reaching-source proof.
  assert_eq(get_consts[final_read], None)
}

///|
test "mass value audit direct HOT propagation preserves nested conditional writes" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32) i32.const 7 local.tee 1 if (result i32) local.get 0 if i32.const 9 local.set 1 end local.get 1 else i32.const 0 end))",
  )
  let module_ctx = @ir.hot_module_context_from_module(input)
  for capture in [false, true] {
    let func = @ir.hot_lift_func_with_context_result(
      input,
      @lib.FuncIdx::new(0U),
      module_ctx,
      capture_stack_locals=capture,
    ).unwrap()
    let ctx = HotPassContext::new(
      precompute_propagate_descriptor(),
      @ir.HotAnalysisCache::new(),
      HotPipelineVerifyPolicy::after_each_pass(),
      false,
      fn(_) { () },
      module_ctx=Some(module_ctx),
    )
    ignore(precompute_propagate_run(ctx, func))
    let rewritten = @ir.hot_lower_func(func)
    let output = input.with_code_sec(@lib.CodeSec::new([rewritten]))
    @validate.validate_module(output).unwrap()
    assert_eq(mass_audit_values_run(rewritten, [0L]), [7L])
    assert_eq(mass_audit_values_run(rewritten, [1L]), [9L])
  }
}

///|
test "mass value audit precompute folds arithmetic inside legacy try and catch" {
  for fold_handler in [false, true] {
    let seed = pass_test_module_from_wat(
      "(module (tag) (func (result i32) i32.const 0))",
    )
    let sum = [
      @lib.Instruction::i32_const(@lib.I32(2)),
      @lib.Instruction::i32_const(@lib.I32(3)),
      @lib.Instruction::i32_add(),
    ]
    let body = if fold_handler {
      [@lib.Instruction::throw_(@lib.TagIdx::new(0U))]
    } else {
      sum
    }
    let handler = if fold_handler {
      sum
    } else {
      [@lib.Instruction::i32_const(@lib.I32(4))]
    }
    let input = seed.with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::try_(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new(body),
              [
                @lib.LegacyCatch::tagged(
                  @lib.TagIdx::new(0U),
                  @lib.Expr::new(handler),
                ),
              ],
            ),
          ]),
        ),
      ]),
    )
    @validate.validate_module(input).unwrap()
    for name in ["precompute", "precompute-propagate"] {
      let output = run_hot_pipeline(input, HotPipelineOptions::new(), [name]).unwrap()
      @validate.validate_module(output).unwrap()
      let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
      assert_eq(
        mass_audit_values_count(body, fn(instr) { instr is @lib.I32Add }),
        0,
        msg=name,
      )
      assert_eq(
        mass_audit_values_count(body, fn(instr) {
          instr is @lib.I32Const(@lib.I32(5))
        }),
        1,
        msg=name,
      )
      assert_eq(
        mass_audit_values_count(body, fn(instr) {
          instr is @lib.Try(_, _, _, _)
        }),
        1,
      )
    }
  }
}

///|
test "mass value audit an unrelated legacy try does not block immutable global folding" {
  let seed = pass_test_module_from_wat(
    "(module (global $g i32 (i32.const 7)) (func nop) (func (result i32) global.get $g))",
  )
  let funcs = seed.code_sec.unwrap().0.copy()
  funcs[0] = @lib.Func::new(
    @lib.Locals::empty(),
    @lib.Expr::new([
      @lib.Instruction::try_(
        @lib.BlockType::void_(),
        @lib.Expr::new([@lib.Instruction::nop()]),
        [@lib.LegacyCatch::all(@lib.Expr::new([@lib.Instruction::nop()]))],
      ),
    ]),
  )
  let input = seed.with_code_sec(@lib.CodeSec::new(funcs))
  @validate.validate_module(input).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "simplify-globals-optimizing",
  ]).unwrap()
  @validate.validate_module(output).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[1]
  assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(7))])
  assert_eq(output.code_sec.unwrap().0[0], input.code_sec.unwrap().0[0])
}
