///|
test "local-subtyping prefilter detects only writes to ref body locals" {
  let base_nullable = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
  )
  let mask = match
    ls_ref_body_local_mask(
      @lib.Locals::from_types([
        @lib.ValType::i32(),
        base_nullable,
        @lib.ValType::i64(),
      ]),
    ) {
    Some(mask) => mask
    None => fail("expected ref body local mask")
  }
  @debug.assert_eq(mask, [false, true, false])
  assert_false(
    ls_expr_writes_ref_body_local(
      @lib.Expr::new([
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::local_set(@lib.LocalIdx::new(2U))]),
        ),
      ]),
      2,
      mask,
    ),
  )
  assert_true(
    ls_expr_writes_ref_body_local(
      @lib.Expr::new([
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [@lib.Instruction::local_set(@lib.LocalIdx::new(3U))],
          Some([
            @lib.Instruction::try_table(
              @lib.BlockType::void_(),
              [],
              @lib.Expr::new([
                @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
              ]),
            ),
          ]),
        ),
      ]),
      2,
      mask,
    ),
  )
  match ls_ref_body_local_mask(@lib.Locals::from_types([@lib.ValType::i32()])) {
    Some(other) => fail("expected no ref body locals, got \{other}")
    None => ()
  }
}

///|
test "local-subtyping raw assignment scan keeps unreachable null bottoms" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $f (func (result i32)))
      #|  (elem declare func $f)
      #|  (func $f (type $f) (result i32)
      #|    (local funcref)
      #|    (local.set 0 (ref.func $f))
      #|    unreachable
      #|    (drop (local.tee 0 (ref.null func)))
      #|    (local.set 0 (ref.null func))
      #|    unreachable))
    ),
  )
  let func = match mod_.code_sec {
    Some(@lib.CodeSec([func])) => func
    other => fail("expected one function, got \{other}")
  }
  let @lib.Func(locals, body) = func
  let module_ctx = @ir.hot_module_context_from_module(mod_)
  let (refined_body, refined_changed) = ls_refine_selects_expr(
    body,
    [],
    locals,
    module_ctx,
  )
  assert_true(refined_changed)
  let refined_pretty = mod_
    .with_code_sec(@lib.CodeSec::new([@lib.Func::new(locals, refined_body)]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(refined_pretty.contains("AbsHeapType NoFunc"), msg=refined_pretty)
  let mask = match ls_ref_body_local_mask(locals) {
    Some(mask) => mask
    None => fail("expected ref-local mask")
  }
  let assigned = ls_collect_raw_assignments(
    body,
    [],
    locals,
    mask,
    module_ctx,
    unknown_falls_back=false,
  )
  @debug.assert_eq(assigned.length(), 1)
  @debug.assert_eq(assigned[0].length(), 3)
  @debug.assert_eq(
    assigned[0][0],
    @lib.ValType::ref_type(
      @lib.RefType::new(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
        exact=true,
      ),
    ),
  )
  let nullfuncref = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::no_func())),
  )
  @debug.assert_eq(assigned[0][1], nullfuncref)
  @debug.assert_eq(assigned[0][2], nullfuncref)
  @debug.assert_eq(
    ls_candidate_local_type(
      @lib.ValType::funcref(),
      assigned[0],
      module_ctx,
      false,
    ),
    Some(
      @lib.ValType::ref_type(
        @lib.RefType::new(
          true,
          @lib.HeapType::new(@lib.TypeIdx::new(0U)),
          exact=true,
        ),
      ),
    ),
  )
}

///|
test "local-subtyping refinalizes reference control results" {
  let mod_ = pass_test_module_from_wat(
    (
      #|(module
      #|  (func (param i32)
      #|    (drop
      #|      (if (result anyref)
      #|        (local.get 0)
      #|        (then (ref.i31 (i32.const 0)))
      #|        (else (ref.i31 (i32.const 1)))))
      #|    (drop
      #|      (block $exit (result anyref)
      #|        (br $exit (ref.i31 (i32.const 0)))
      #|        (ref.i31 (i32.const 1))))))
    ),
  )
  let optimized = local_subtyping_run_module_pass(mod_)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("AbsHeapType I31"), msg=pretty)
  assert_false(pretty.contains("AbsHeapType Any"), msg=pretty)
}

///|
test "local-subtyping follows the validator abstract heap hierarchy" {
  assert_false(
    ls_abs_heap_is_subtype(@lib.AbsHeapType::func(), @lib.AbsHeapType::any()),
  )
  assert_false(
    ls_abs_heap_is_subtype(@lib.AbsHeapType::extern_(), @lib.AbsHeapType::any()),
  )
  assert_false(
    ls_abs_heap_is_subtype(@lib.AbsHeapType::no_func(), @lib.AbsHeapType::any()),
  )
  assert_true(
    ls_abs_heap_is_subtype(@lib.AbsHeapType::none(), @lib.AbsHeapType::i31()),
  )
  assert_true(
    ls_abs_heap_is_subtype(
      @lib.AbsHeapType::no_cont(),
      @lib.AbsHeapType::cont(),
    ),
  )
  assert_true(
    ls_abs_heap_is_subtype(
      @lib.AbsHeapType::string_(),
      @lib.AbsHeapType::extern_(),
    ),
  )
}
