///|
test "precompute skips load-call-set ownership hazards" {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (import "m" "decref" (func $decref (param i32)))
        #|  (memory 1)
        #|  (func (param $cell i32) (result i32)
        #|    (local $out i32)
        #|    local.get $cell
        #|    i32.load offset=8
        #|    local.get $cell
        #|    call $decref
        #|    local.set $out
        #|    i32.const 0
        #|    i32.eqz
        #|    drop
        #|    local.get $out))
        #|,
      ),
      ["precompute"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected load-call-set precompute success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[precompute]:skip-raw reason=load-call-set-precompute-noop",
      )
    }),
  )
}

///|
test "precompute runs narrow raw scalar folds under O4z gate" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 1 i32.const 2 i32.add))",
      ["precompute"],
      options=HotPipelineOptions::new(
        optimize_level=4,
        shrink_level=1,
        trace=Some(fn(line) { trace.push(line) }),
      ),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected O4z scalar precompute success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(3)"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[precompute]:skip-raw reason=raw-scalar-folds")
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute applies proven selector-only O4z control cleanup" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func block $exit i32.const 1 br_table $exit $exit end unreachable))",
      ["precompute"],
      options=HotPipelineOptions::new(
        optimize_level=4,
        shrink_level=1,
        trace=Some(fn(line) { trace.push(line) }),
      ),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected O4z precompute skip success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("br_table"), msg=pretty)
  assert_false(pretty.contains("(block"), msg=pretty)
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[precompute]:skip-raw reason=raw-control-flow-folds")
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute folds exact i32 constant arithmetic" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 4 i32.const 5 i32.add))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected precompute success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(9)"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
}

///|
test "precompute folds ref.is_null of an exact ref.null" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) ref.null none ref.is_null))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ref-null precompute success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("ref.is_null"), msg=pretty)
  assert_false(pretty.contains("ref.null"), msg=pretty)
}

///|
test "precompute folds typed ref.is_null after DAE local compaction" {
  let source =
    #|(module
    #|  (type $box (struct (field i32)))
    #|  (func (result i32) (local (ref null $box))
    #|    ref.null $box
    #|    ref.is_null))
  let optimized = match pass_test_run_pipeline(source, ["precompute"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected typed ref-null precompute success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("ref.is_null"), msg=pretty)
}

///|
test "precompute hot path folds typed ref.is_null of ref.null" {
  let source =
    #|(module
    #|  (type $box (struct (field i32)))
    #|  (func (result i32)
    #|    ref.null $box
    #|    ref.is_null))
  let mod_ = pass_test_module_from_wat(source)
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    precompute_propagate_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  let result = precompute_propagate_run(ctx, func)
  assert_true(result.changed)
  @ir.hot_verify_all_or_abort(func)
  let pretty = mod_
    .with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("ref.is_null"), msg=pretty)
}

///|
test "precompute folds chained exact constants in one pass" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 1 i32.const 2 i32.const 3 i32.add i32.add))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected chained precompute success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(6)"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
}

///|
test "precompute folds exact i64 unsigned comparisons to i32 constants" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i64.const -1 i64.const 0 i64.gt_u))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected precompute unsigned compare success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("i64.gt_u"), msg=pretty)
}

///|
test "precompute preserves trapping exact operators it does not fold" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 1 i32.const 0 i32.div_s))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected precompute div_s success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.div_s"), msg=pretty)
}

///|
test "precompute preserves dropped zero-divisor traps after unsigned canonicalization" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (type (func (result i32 i64))) (func block (type 0) i32.const 1 i32.const 0 i32.div_s drop i32.const 7 i64.const 9 end drop drop))",
      ["optimize-instructions", "precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected precompute dropped div success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.div_u"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
}

///|
test "precompute-propagate folds constant selects while retaining chosen effects" {
  let pretty = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (global $state (mut i32) (i32.const 0))
        #|  (func (result i32)
        #|    (select
        #|      (i32.const 1)
        #|      (block (result i32)
        #|        (global.set $state (i32.const 7))
        #|        (i32.const 2))
        #|      (i32.const 0))))
        #|,
      ),
      ["precompute-propagate"],
    ) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected effectful select folding, got \{err}")
  }
  assert_false(pretty.contains("select"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("I32(2)"), msg=pretty)
}

///|
test "precompute-propagate folds constant-true branches after loop effects" {
  let pretty = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (result i32)
        #|    (local $value i32)
        #|    (loop $again
        #|      (local.set $value (i32.const 0))
        #|      (br_if $again (i32.const 1))
        #|      (local.set $value (i32.const 9)))
        #|    (i32.const 10)))
        #|,
      ),
      ["precompute-propagate"],
    ) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected effectful loop branch folding, got \{err}")
  }
  assert_true(pretty.contains("br (Label 0)"), msg=pretty)
  assert_false(pretty.contains("br_if"), msg=pretty)
  assert_false(pretty.contains("I32(9)"), msg=pretty)
  assert_false(pretty.contains("I32(10)"), msg=pretty)
}

///|
test "precompute propagates an escaping branch through constant if and numeric parents" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (result f64)
        #|    (block $out (result f64)
        #|      (i32.store8
        #|        (i32.const 0)
        #|        (if (result i32) (i32.const 1)
        #|          (then
        #|            (block $inner (result i32)
        #|              (drop
        #|                (i64.and
        #|                  (i64.trunc_f32_u (f32.const 70847791997969805621592064))
        #|                  (i64.const 729618461987467893)))
        #|              (br_if $inner
        #|                (i32.const 3)
        #|                (f32.eq
        #|                  (f32.demote_f64
        #|                    (f64.mul
        #|                      (br_if $out (f64.const 4) (i32.const 1))
        #|                      (f64.const 5)))
        #|                  (f32.const 6)))))
        #|          (else (i32.const 7))))
        #|      (f64.const 8))))
        #|,
      ),
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected escaping branch flow fold, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("F64(4"), msg=pretty)
  assert_false(pretty.contains("br_if"), msg=pretty)
  assert_false(pretty.contains("f64.mul"), msg=pretty)
  assert_false(pretty.contains("local.set"), msg=pretty)
}

///|
test "precompute does not treat a conditionally self-exiting block as an outer terminator" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (param i32) (result i32)
        #|    (block $outer
        #|      (block $inner
        #|        (br_if $inner (local.get 0))
        #|        (br $outer))
        #|      (return (i32.const 1)))
        #|    (i32.const 2)))
        #|,
      ),
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected conditional block flow preservation, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(pretty.contains("I32(2)"), msg=pretty)
  assert_true(pretty.contains("br_if"), msg=pretty)
}

///|
test "precompute folds a block-local read after preserving its constant write" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i64) (local i64) (block (result i64) (local.set 0 (i64.const 42)) (local.get 0))))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected block-local constant fold, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_true(pretty.contains("I64(42)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "precompute folds loop-carried constant breaks to the enclosing result" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (block (result i32) (loop (br 1 (i32.const 1))))))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected loop break result fold, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("loop"), msg=pretty)
  assert_false(pretty.contains("br ("), msg=pretty)
}

///|
test "precompute preserves every payload of a flattened multivalue branch" {
  let source =
    #| (module
    #|   (type $pair (func (result i32 i64)))
    #|   (func (result i32 i64)
    #|     (block (type $pair)
    #|       (block
    #|         i32.const 1
    #|         i64.const 2
    #|         br 1)
    #|       unreachable)))
    #|
  for pass_name in ["precompute", "precompute-propagate"] {
    let trace : Array[String] = []
    let optimized = match
      pass_test_run_pipeline(
        source,
        [pass_name],
        options=HotPipelineOptions::new(
          trace=Some(fn(line) { trace.push(line) }),
        ),
      ) {
      Ok(mod_) => mod_
      Err(err) =>
        fail(
          "expected \{pass_name} multivalue branch preservation, got \{err}; trace=\{trace}",
        )
    }

    assert_false(
      trace.any(fn(line) { line.contains("skip-invalid-lower") }),
      msg=trace.to_string(),
    )
    match @validate.validate_module(optimized) {
      Ok(_) => ()
      Err(err) =>
        fail("expected \{pass_name} multivalue output to validate, got \{err}")
    }
    let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
    assert_true(pretty.contains("I32(1)"), msg=pretty)
    assert_true(pretty.contains("I64(2)"), msg=pretty)
  }
}

///|
test "precompute drops every dead value of a flattened void branch" {
  let source = "(module (func (block (i32.const 1) (br 0))))"
  for pass_name in ["precompute", "precompute-propagate"] {
    let trace : Array[String] = []
    let optimized = match
      pass_test_run_pipeline(
        source,
        [pass_name],
        options=HotPipelineOptions::new(
          trace=Some(fn(line) { trace.push(line) }),
        ),
      ) {
      Ok(mod_) => mod_
      Err(err) => fail("expected \{pass_name} void branch cleanup, got \{err}")
    }
    assert_false(
      trace.any(fn(line) { line.contains("skip-invalid-lower") }),
      msg=trace.to_string(),
    )
    match @validate.validate_module(optimized) {
      Ok(_) => ()
      Err(err) => fail("expected \{pass_name} void branch output, got \{err}")
    }
  }
}

///|
test "precompute preserves label depth while folding a constant if with an escaping value" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (result i32)
        #|    (block $out (result i32)
        #|      (i32.add
        #|        (if (result i32) (i32.const 1)
        #|          (then (br $out (i32.const 7)))
        #|          (else (i32.const 8)))
        #|        (i32.const 9)))))
        #|,
      ),
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected escaping constant-if fold, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("if "), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
}

///|
test "precompute folds loop-carried constant breaks before an unreachable tail" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (block (result i32) (loop (br 1 (i32.const 1))) (unreachable))))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected loop break with unreachable tail fold, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("loop"), msg=pretty)
  assert_false(pretty.contains("br ("), msg=pretty)
}

///|
test "precompute removes constant-false self-branch loop debris" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (export "main")
        #|    (loop (br_if 0 (i32.const 0)))
        #|    (i32.const 7)
        #|    (drop)))
        #|,
      ),
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected precompute false loop cleanup success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("loop"), msg=pretty)
  assert_false(pretty.contains("br_if"), msg=pretty)
}

///|
test "precompute folds constant br-if and self-branch debris" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (export "main")
        #|    (loop (br_if 0 (i32.const 1)))
        #|    (block (br_if 0 (i32.const 0)))
        #|    (block (br 0))))
        #|,
      ),
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected precompute branch debris cleanup success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("br_if"), msg=pretty)
  assert_false(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("I32(0)"), msg=pretty)
}

///|
test "precompute intentionally preserves reachable atomic fence before branch-to-end" {
  // Boundary guard: Binaryen currently removes this fence under `--precompute`,
  // but Starshine keeps `atomic.fence` as an ordering barrier. Do not widen the
  // precompute branch cleanup to erase reachable atomics just to clear raw
  // output drift.
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::atomic_fence(),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
            @lib.Instruction::atomic_fence(),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["precompute"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected precompute atomic-fence branch preservation success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("atomic.fence"), msg=pretty)
  assert_true(pretty.contains("br ("), msg=pretty)
}

///|
test "precompute raw-cleans supported values around unsupported atomic fences" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::atomic_fence(),
            @lib.Instruction::i32_const(@lib.I32(84)),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::i32_div_s(),
            @lib.Instruction::drop(),
            @lib.Instruction::f64_const(@lib.F64(1.5)),
            @lib.Instruction::f64_const(@lib.F64(2.25)),
            @lib.Instruction::f64_add(),
            @lib.Instruction::drop(),
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32(0)),
                @lib.Instruction::br_table(
                  [@lib.LabelIdx::new(0U)],
                  @lib.LabelIdx::new(0U),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let pretty = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["precompute"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected plain atomic raw cleanup success, got \{err}")
  }
  assert_true(pretty.contains("atomic.fence"), msg=pretty)
  assert_false(pretty.contains("i32.div_s"), msg=pretty)
  assert_false(pretty.contains("f64.add"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
}

///|
test "precompute raw-collapses an unreachable value block after an atomic fence" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::atomic_fence(),
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([@lib.Instruction::unreachable_()]),
            ),
            @lib.Instruction::atomic_fence(),
          ]),
        ),
      ]),
    )
  let pretty = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["precompute"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) =>
      fail("expected raw unreachable block cleanup success, got \{err}")
  }
  assert_true(pretty.contains("unreachable"), msg=pretty)
  @debug.assert_eq(pretty.split("atomic.fence").length(), 2)
}

///|
test "precompute folds constant false void ifs away" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func i32.const 0 if nop else nop end i64.const 3 drop))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected precompute if-fold success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("I64(3)"), msg=pretty)
}

///|
test "precompute folds constant true result ifs to the chosen arm" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 1 if (result i32) i32.const 7 else i32.const 9 end))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected precompute result-if fold success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "precompute preserves labels when folding nested constant void ifs" {
  let source =
    #|(module
    #|  (type $result (func (param i32) (result i32)))
    #|  (type $sink (func (param i32)))
    #|  (memory 4)
    #|  (global $g0 i32 (i32.const 205200))
    #|  (global $g1 i32 (i32.const 205220))
    #|  (global $g2 i32 (i32.const 205240))
    #|  (global $g3 i32 (i32.const 205260))
    #|  (global $g4 i32 (i32.const 205280))
    #|  (global $g5 i32 (i32.const 205300))
    #|  (global $g6 i32 (i32.const 205320))
    #|  (global $g7 i32 (i32.const 205340))
    #|  (global $g8 i32 (i32.const 205360))
    #|  (global $g9 i32 (i32.const 205380))
    #|  (func $mark (type $sink) (param i32))
    #|  (func $touch (type $sink) (param i32))
    #|  (func (export "f") (type $result) (param i32) (result i32)
    #|    (local i32)
    #|    local.get 0
    #|    i32.load offset=8 align=1
    #|    local.set 1
    #|    block (result i32)
    #|      block
    #|        block
    #|          block
    #|            block
    #|              block
    #|                block
    #|                  block
    #|                    block
    #|                      block
    #|                        block
    #|                          block
    #|                            local.get 1
    #|                            i32.const 31
    #|                            i32.sub
    #|                            br_table 0 1 2 3 4 5 6 7 8 9 10
    #|                          end
    #|                          local.get 0
    #|                          call $touch
    #|                          global.get $g0
    #|                          if
    #|                            global.get $g0
    #|                            call $mark
    #|                          end
    #|                          global.get $g0
    #|                          br 10
    #|                        end
    #|                        local.get 0
    #|                        call $touch
    #|                        global.get $g1
    #|                        if
    #|                          global.get $g1
    #|                          call $mark
    #|                        end
    #|                        global.get $g1
    #|                        br 9
    #|                      end
    #|                      local.get 0
    #|                      call $touch
    #|                      global.get $g2
    #|                      if
    #|                        global.get $g2
    #|                        call $mark
    #|                      end
    #|                      global.get $g2
    #|                      br 8
    #|                    end
    #|                    local.get 0
    #|                    call $touch
    #|                    global.get $g3
    #|                    if
    #|                      global.get $g3
    #|                      call $mark
    #|                    end
    #|                    global.get $g3
    #|                    br 7
    #|                  end
    #|                  local.get 0
    #|                  call $touch
    #|                  global.get $g4
    #|                  if
    #|                    global.get $g4
    #|                    call $mark
    #|                  end
    #|                  global.get $g4
    #|                  br 6
    #|                end
    #|                local.get 0
    #|                call $touch
    #|                global.get $g5
    #|                if
    #|                  global.get $g5
    #|                  call $mark
    #|                end
    #|                global.get $g5
    #|                br 5
    #|              end
    #|              local.get 0
    #|              call $touch
    #|              global.get $g6
    #|              if
    #|                global.get $g6
    #|                call $mark
    #|              end
    #|              global.get $g6
    #|              br 4
    #|            end
    #|            local.get 0
    #|            call $touch
    #|            global.get $g7
    #|            if
    #|              global.get $g7
    #|              call $mark
    #|            end
    #|            global.get $g7
    #|            br 3
    #|          end
    #|          local.get 0
    #|          call $touch
    #|          global.get $g8
    #|          if
    #|            global.get $g8
    #|            call $mark
    #|          end
    #|          global.get $g8
    #|          br 2
    #|        end
    #|        local.get 0
    #|        call $touch
    #|        global.get $g9
    #|        if
    #|          global.get $g9
    #|          call $mark
    #|        end
    #|        global.get $g9
    #|        br 1
    #|      end
    #|      local.get 0
    #|      call $touch
    #|      i32.const 0
    #|      br 0
    #|    end))
    #|)
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      source,
      ["precompute"],
      options=HotPipelineOptions::new(
        verify_policy=HotPipelineVerifyPolicy::after_each_pass(),
        trace=Some(fn(line) { trace.push(line) }),
      ),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected precompute to preserve folded-if labels, got \{err}")
  }
  for line in trace {
    assert_false(
      line.contains("precompute-hot-label-owner-noop"),
      msg="unexpected fail-closed precompute skip: \{line}",
    )
  }
}

///|
test "precompute rehomes labels when folding constant ifs to blocks" {
  let source =
    #|(module
    #|  (func (result i32)
    #|    i32.const 1
    #|    if (result i32)
    #|      i32.const 0
    #|      drop
    #|      block (result i32)
    #|        i32.const 42
    #|      end
    #|    else
    #|      i32.const 7
    #|    end))
    #|)
  match pass_test_run_pipeline(source, ["precompute"]) {
    Ok(_) => ()
    Err(err) =>
      fail("expected precompute folded block label owner success, got \{err}")
  }
}

///|
test "precompute retargets split local.set wrappers with void-if forwarders" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) (local.set 1 (block $outer (result i32) (block $exit (br $outer (block $mid (result i32) (block $cont (if (local.get 0) (then (local.set 2 (i32.const 7)) (br $cont)) (else (local.set 2 (i32.const 9)) (br $exit))) unreachable) (local.get 2)))) (local.get 1))) (local.get 1)))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected precompute split-wrapper success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(block $outer (result i32)"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "precompute folds after early cleanup exposes constants" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) block (result i32) i32.const 41 i32.const 1 i32.add end))",
      ["vacuum", "precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected early cleanup precompute success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(42)"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
}

///|
test "precompute leaves late cleanup-ready nops around dead exact roots" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 2 i32.const 3 i32.mul drop i32.const 9))",
      ["precompute", "vacuum"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected late cleanup precompute success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(9)"), msg=pretty)
  assert_false(pretty.contains("i32.mul"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
}

///|
test "precompute removes direct self-targeting branch blocks" {
  let optimized = match
    pass_test_run_pipeline("(module (func block br 0 end))", ["precompute"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected direct self-target branch cleanup success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("br ("), msg=pretty)
  assert_false(pretty.contains("(block"), msg=pretty)
  assert_true(pretty.contains("nop"), msg=pretty)
}

///|
test "precompute removes selector-only self-targeting br_table blocks" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) block $exit i32.const 1 br_table $exit $exit end unreachable))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected precompute self-target br_table success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("br_table"), msg=pretty)
  assert_false(pretty.contains("(block"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "precompute removes dropped pure constants from void bodies" {
  let optimized = match
    pass_test_run_pipeline("(module (func i64.const 360 drop))", ["precompute"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected precompute pure-drop success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("I64(360)"), msg=pretty)
}

///|
test "precompute normalizes empty void bodies to one nop" {
  let optimized = match
    pass_test_run_pipeline("(module (func))", ["precompute"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected precompute empty-body success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("nop"), msg=pretty)
}

///|
test "precompute collapses newly all-nop bodies to one stable nop" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func i32.const 1 drop i64.const 2 drop f32.const 3 drop))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected all-nop collapse success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(pretty.split("nop").length(), 2)
  assert_false(pretty.contains("drop"), msg=pretty)
}

///|
test "precompute replaces orphan scalar values before unreachable with stable nops" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i64) nop i32.const 1 f32.const 0 unreachable))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected orphan-value unreachable cleanup success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("F32("), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
}

///|
test "precompute collapses typed blocks with only dead values before unreachable" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i32) memory.size drop (block (result i64) f64.const 1 unreachable) unreachable))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected typed unreachable block cleanup success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("F64("), msg=pretty)
  assert_false(pretty.contains("(block"), msg=pretty)
}

///|
test "precompute removes orphan values across empty try tables before unreachable" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func f32.const 0 (try_table (catch_all 0)) unreachable))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected empty try-table unreachable cleanup success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("try_table"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("F32("), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
}

///|
test "precompute leaves a dead exact root nop before unreachable" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func i32.const 2 i32.const 3 i32.mul drop unreachable))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected precompute dead-root nop success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("nop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("i32.mul"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
}

///|
test "precompute removes pure root nop prefixes before a final const result" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (global i64 (i64.const 486)) (func (result i32) i32.const 1 if nop else nop end f64.const 45 drop global.get 0 drop nop nop nop i32.const 655))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected precompute nop-residue cleanup success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("nop"), msg=pretty)
  assert_true(pretty.contains("I32(655)"), msg=pretty)
}

///|
test "precompute marks constant-true self-branch loop tails unreachable after block debris" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (result i32)
        #|    i32.const 0
        #|    drop
        #|    (loop i32.const 1 br_if 0)
        #|    (block br 0)
        #|    i32.const 310))
        #|,
      ),
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected precompute block-debris loop tail cleanup success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(loop"), msg=pretty)
  assert_true(pretty.contains("br (Label 0)"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("br_if"), msg=pretty)
  assert_false(pretty.contains("I32(310)"), msg=pretty)
}

///|
test "precompute marks constant-true self-branch loop tails unreachable" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (loop i32.const 1 br_if 0) i32.const 310))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected precompute self-branch loop tail cleanup success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(loop"), msg=pretty)
  assert_true(pretty.contains("br (Label 0)"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("br_if"), msg=pretty)
  assert_false(pretty.contains("I32(310)"), msg=pretty)
}

///|
test "precompute removes constant self-exiting blocks before a final const result" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 1 drop (block i32.const 1 br_if 0) nop i32.const 134))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected precompute self-exiting-block cleanup success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("(block"), msg=pretty)
  assert_false(pretty.contains("nop"), msg=pretty)
  assert_true(pretty.contains("I32(134)"), msg=pretty)
}

///|
test "precompute removes a leading nop before a final const result" {
  let optimized = match
    pass_test_run_pipeline("(module (func (result i32) nop i32.const 363))", [
      "precompute",
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected precompute leading-nop const success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("nop"), msg=pretty)
  assert_true(pretty.contains("I32(363)"), msg=pretty)
}

///|
test "precompute preserves explicit nops before a trailing local.get result" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result f32) (local i32 f32) nop nop local.get 1))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected precompute trailing-local-get nop parity, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("nop"), msg=pretty)
  assert_true(pretty.contains("(local.get (Local 1))"), msg=pretty)
}

///|
test "precompute keeps the surviving pure prefix rewrite before a trailing const" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (global i32 (i32.const 212)) (func (param f32 i64) (result i32) nop global.get 0 drop f32.const 78 drop i64.const 756 local.set 1 nop nop i32.const 700))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected precompute dead-prefix nop parity success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("(local.set (Local 1))"), msg=pretty)
  assert_true(pretty.contains("I32(700)"), msg=pretty)
}

///|
test "precompute lowers empty root blocks away before surviving roots" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param f32) (result f32) (local f32) i64.const 942 drop f32.const 80 local.tee 0 drop block nop end f32.const 5 local.set 1 block nop end local.get 0))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected precompute root-block nop parity success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(block"), msg=pretty)
  assert_true(pretty.contains("(local.set (Local 1))"), msg=pretty)
  assert_true(pretty.contains("(local.get (Local 0))"), msg=pretty)
}

///|
test "precompute keeps the structured branch-exit body valid after folding dead exact prefixes" {
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      pass_test_module_from_wat(
        "(module (func (param i32) (result i32) (local i32 i32) i32.const 0 i32.const 2 i32.shl drop (block $outer i32.const 0 drop (block $mid (local.get 0) (if (result i32) (then (i32.const 7) (local.set 1) (br $mid)) (else (i32.const 9) (local.set 2) (br $outer))) return) (local.get 1) (local.set 2)) (i32.const 0)))",
      ),
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected guarded precompute success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("i32.shl"), msg=pretty)
  assert_false(
    trace.any(fn(line) { line.contains("pass[precompute]:skip-invalid-lower") }),
    msg=trace.to_string(),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected structured branch-exit precompute output to validate, got \{err}",
      )
  }
}

///|
test "precompute folds nested exact i32 bit-arithmetic to a single const" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 177248 i32.const 15 i32.add i32.const -16 i32.and))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nested exact i32 bit-arithmetic fold success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(177248)"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
  assert_false(pretty.contains("i32.and"), msg=pretty)
}

///|
test "precompute repairs stale MoonBit tlsf init dropped counter increments" {
  let source =
    #|(module
    #|  (func (local i32 i32)
    #|    loop
    #|      i32.const 0
    #|      local.tee 0
    #|      i32.const 23
    #|      i32.lt_u
    #|      if
    #|        loop
    #|          i32.const 0
    #|          local.tee 1
    #|          i32.const 16
    #|          i32.lt_u
    #|          if
    #|            local.get 1
    #|            i32.const 1
    #|            i32.add
    #|            drop
    #|            br 1
    #|          end
    #|        end
    #|        local.get 0
    #|        i32.const 1
    #|        i32.add
    #|        drop
    #|        br 1
    #|      end
    #|    end))
    #|)
  let optimized = match pass_test_run_pipeline(source, ["precompute"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected tlsf counter repair success, got \{err}")
  }

  let text = optimized.to_string()
  assert_false(text.contains("Drop"), msg=text)
}

///|
test "precompute repairs stale MoonBit tlsf memory prologue and counters" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func (local i32 i32 i32 i32 i32)
    #|    memory.size
    #|    i32.const 177263
    #|    i32.const -16
    #|    i32.and
    #|    local.tee 0
    #|    i32.const 67107
    #|    i32.add
    #|    i32.const -65536
    #|    i32.and
    #|    i32.const 16
    #|    i32.shr_u
    #|    i32.lt_s
    #|    if (result i32)
    #|      local.get 3
    #|      local.get 4
    #|      i32.sub
    #|      memory.grow
    #|      i32.const 0
    #|      i32.lt_s
    #|    else
    #|      i32.const 0
    #|    end
    #|    if
    #|      unreachable
    #|    end
    #|    loop
    #|      i32.const 0
    #|      local.tee 1
    #|      i32.const 23
    #|      i32.lt_u
    #|      if
    #|        loop
    #|          i32.const 0
    #|          local.tee 2
    #|          i32.const 16
    #|          i32.lt_u
    #|          if
    #|            br 1
    #|          end
    #|        end
    #|        br 1
    #|      end
    #|    end))
    #|)
  let optimized = match pass_test_run_pipeline(source, ["precompute"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected tlsf prologue repair success, got \{err}")
  }

  let text = optimized.to_string()
  assert_false(text.contains("LocalTee"), msg=text)
  assert_true(text.contains("LocalSet"), msg=text)
  assert_true(text.contains("I32LtS"), msg=text)
}

///|
test "precompute folds exact i32 shift expressions to constants" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32 i32) i32.const 8 i32.const 2 i32.shr_u i32.const 3 i32.const 30 i32.shl))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected exact i32 shift fold success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(2)"), msg=pretty)
  assert_true(pretty.contains("I32(-1073741824)"), msg=pretty)
  assert_false(pretty.contains("i32.shr_u"), msg=pretty)
  assert_false(pretty.contains("i32.shl"), msg=pretty)
}

///|
test "precompute folds immutable global.get uses into constants" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (global i32 (i32.const 169776)) (func (result i32) global.get 0))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected immutable global.get fold success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(169776)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "precompute folds defined immutable globals even after imported globals" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (import \"env\" \"g\" (global i32)) (global i32 (i32.const 169776)) (func (result i32) global.get 1))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected defined immutable global.get after imports to fold, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(169776)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
}

///|
test "precompute validates rewritten functions against full module call targets" {
  let input = "(module (import \"env\" \"sink\" (func (param i32))) (global i32 (i32.const 169776)) (global i32 (i32.const 169472)) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) global.get 0 local.set 9 i32.const 0 local.set 0 i32.const 0 local.set 1 i32.const 0 local.set 2 i32.const 0 local.set 3 i32.const 0 local.set 4 i32.const 0 local.set 5 i32.const 0 local.set 6 global.get 1 call 0 global.get 1 local.set 7 i32.const 0 local.set 8 local.get 0 local.get 1 local.get 2 local.get 3 local.get 4 local.get 5 local.get 6 local.get 7 local.get 8 call 2) (func (param i32 i32 i32 i32 i32 i32 i32 i32 i32) (result i32) local.get 0))"
  let trace = match pass_test_capture_trace(input, ["precompute"]) {
    Ok(lines) => lines
    Err(err) =>
      fail(
        "expected precompute call-target validation repro success, got \{err}",
      )
  }
  let optimized = match pass_test_run_pipeline(input, ["precompute"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected precompute full-module validation regression success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("I32(169776)"), msg=pretty)
  assert_true(pretty.contains("I32(169472)"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(
    trace.any(fn(line) { line.contains("pass[precompute]:skip-invalid-lower") }),
    msg=trace.to_string(),
  )
}

///|
test "precompute folds safe exact integer division" {
  let pretty = match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 84 i32.const 3 i32.div_s))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected exact division precompute success, got \{err}")
  }
  assert_true(pretty.contains("I32(28)"), msg=pretty)
  assert_false(pretty.contains("i32.div_s"), msg=pretty)
}

///|
test "precompute folds exact floating point arithmetic" {
  let pretty = match
    pass_test_run_pipeline(
      "(module (func (result f64) f64.const 1.5 f64.const 2.25 f64.add))",
      ["precompute"],
    ) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected exact floating precompute success, got \{err}")
  }
  assert_true(pretty.contains("F64(3.75)"), msg=pretty)
  assert_false(pretty.contains("f64.add"), msg=pretty)
}

///|
test "precompute partially evaluates parents through select arms" {
  let pretty = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (param i32) (result i32)
        #|    i32.const 10
        #|    i32.const 20
        #|    local.get 0
        #|    select
        #|    i32.const 3
        #|    i32.add))
        #|,
      ),
      ["precompute"],
      options=HotPipelineOptions::new(optimize_level=2),
    ) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected partial select precompute success, got \{err}")
  }
  assert_true(pretty.contains("I32(13)"), msg=pretty)
  assert_true(pretty.contains("I32(23)"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
}

///|
test "precompute folds fresh GC allocation identity against null" {
  let pretty = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (type $s (struct))
        #|  (func (result i32)
        #|    struct.new $s
        #|    ref.null $s
        #|    ref.eq))
        #|,
      ),
      ["precompute"],
    ) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected GC identity precompute success, got \{err}")
  }
  assert_true(pretty.contains("I32(0)"), msg=pretty)
  assert_false(pretty.contains("ref.eq"), msg=pretty)
  assert_false(pretty.contains("struct.new"), msg=pretty)
}

///|
test "precompute folds null identity and propagated null tests" {
  let pretty = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (type $s (struct))
        #|  (func (result i32)
        #|    (ref.eq (ref.null $s) (ref.null $s)))
        #|  (func (result i32)
        #|    (local $x (ref null $s))
        #|    (local.set $x (struct.new $s))
        #|    (ref.is_null (local.get $x)))
        #|  (func (result i32)
        #|    (local $x (ref null $s))
        #|    (local.set $x (ref.null $s))
        #|    (ref.is_null (local.get $x))))
        #|,
      ),
      ["precompute-propagate"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected propagated reference null folding, got \{err}")
  }
  let null_equal = pretty.pretty_print_func(@lib.FuncIdx::new(0U))
  let allocation_non_null = pretty.pretty_print_func(@lib.FuncIdx::new(1U))
  let null_local = pretty.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(null_equal.contains("I32(1)"), msg=null_equal)
  assert_false(null_equal.contains("ref.eq"), msg=null_equal)
  assert_true(allocation_non_null.contains("I32(0)"), msg=allocation_non_null)
  assert_false(
    allocation_non_null.contains("ref.is_null"),
    msg=allocation_non_null,
  )
  assert_true(null_local.contains("I32(1)"), msg=null_local)
  assert_false(null_local.contains("ref.is_null"), msg=null_local)
}

///|
test "precompute-propagate turns nullable null casts and null struct reads into traps" {
  let struct_type = @lib.TypeIdx::new(0U)
  let func_type = @lib.TypeIdx::new(1U)
  let struct_heap = @lib.HeapType::new(struct_type)
  let none_heap = @lib.HeapType::abs(@lib.AbsHeapType::none())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::f64()),
                @lib.Mut::var_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([
            @lib.ValType::ref_type(@lib.RefType::new(true, struct_heap)),
          ]),
          @lib.Expr::new([
            @lib.Instruction::ref_null(none_heap),
            @lib.Instruction::ref_cast(true, none_heap),
            @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::struct_get(struct_type, @lib.U32(0U)),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let pretty = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected null cast and struct trap folding, got \{err}")
  }
  assert_false(pretty.contains("ref.cast"), msg=pretty)
  assert_false(pretty.contains("struct.get"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "precompute-propagate refinalizes exact cast branch block results" {
  let struct_type = @lib.TypeIdx::new(0U)
  let func_type = @lib.TypeIdx::new(1U)
  let heap_type = @lib.HeapType::new(struct_type)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::struct_([]))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [
              @lib.ValType::ref_type(@lib.RefType::new(false, heap_type)),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(
                @lib.ValType::ref_type(@lib.RefType::new(false, heap_type)),
              ),
              @lib.Expr::new([
                @lib.Instruction::struct_new_default(struct_type),
                @lib.Instruction::br_on_cast(
                  @lib.LabelIdx::new(0U),
                  false,
                  heap_type,
                  false,
                  heap_type,
                  source_exact=true,
                  target_exact=true,
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::unreachable_(),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["precompute-propagate"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected exact cast block refinalization, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(body)) = match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => funcs[0]
    None => fail("expected code section")
  }
  match body {
    [@lib.Block(@lib.ValTypeBlockType(@lib.RefTypeValType(result)), _)] =>
      assert_true(result.is_exact(), msg="result=\{result}")
    _ => fail("expected one typed block, got \{body}")
  }
}

///|
test "precompute-propagate collapses aggregate construction after unreachable child" {
  let pretty = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (type $record (struct (field i32)))
        #|  (func (result (ref $record))
        #|    (struct.new $record (unreachable))))
        #|,
      ),
      ["precompute-propagate"],
    ) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected aggregate trap folding, got \{err}")
  }
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("struct.new"), msg=pretty)
}

///|
test "precompute folds ref tests on fresh exact allocations" {
  let struct_type = @lib.TypeIdx::new(0U)
  let func_type = @lib.TypeIdx::new(1U)
  let heap_type = @lib.HeapType::new(struct_type)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(true, [], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::struct_new(struct_type),
            @lib.Instruction::ref_test_type(
              @lib.RefType::new(false, heap_type, exact=true),
            ),
          ]),
        ),
      ]),
    )
  let pretty = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["precompute"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected fresh allocation ref.test success, got \{err}")
  }
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("ref.test"), msg=pretty)
  assert_false(pretty.contains("struct.new"), msg=pretty)
}

///|
test "precompute folds immutable struct reads from fresh allocations" {
  let pretty = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (type $s (struct (field i32)))
        #|  (func (result i32)
        #|    i32.const 42
        #|    struct.new $s
        #|    struct.get $s 0))
        #|,
      ),
      ["precompute"],
    ) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) =>
      fail("expected immutable struct read precompute success, got \{err}")
  }
  assert_true(pretty.contains("I32(42)"), msg=pretty)
  assert_false(pretty.contains("struct.get"), msg=pretty)
  assert_false(pretty.contains("struct.new"), msg=pretty)
}

///|
test "precompute partially folds immutable heap reads across select arms" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (type $box (struct (field i32)))
        #|  (global $a (ref $box) (struct.new $box (i32.const 11)))
        #|  (global $b (ref $box) (struct.new $box (i32.const 22)))
        #|  (func (param i32) (result i32)
        #|    (struct.get $box 0
        #|      (select
        #|        (global.get $a)
        #|        (global.get $b)
        #|        (local.get 0))))
        #|  (func (param i32) (result i32)
        #|    (ref.eq
        #|      (select
        #|        (global.get $a)
        #|        (global.get $b)
        #|        (local.get 0))
        #|      (global.get $a))))
        #|,
      ),
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected partial immutable heap fold, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("select"), msg=pretty)
  assert_true(pretty.contains("I32(11)"), msg=pretty)
  assert_true(pretty.contains("I32(22)"), msg=pretty)
  assert_false(pretty.contains("struct.get"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  let identity = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(identity.contains("select"), msg=identity)
  assert_true(identity.contains("I32(1)"), msg=identity)
  assert_true(identity.contains("I32(0)"), msg=identity)
  assert_false(identity.contains("ref.eq"), msg=identity)
}

///|
test "precompute-propagate folds nested immutable aggregate reads" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (type $inner (struct (field i32)))
        #|  (type $outer (struct (field (ref $inner))))
        #|  (global $inner-global (ref $inner)
        #|    (struct.new $inner (i32.const 84)))
        #|  (func (result i32)
        #|    (local $outer-local (ref null $outer))
        #|    (local.set $outer-local
        #|      (struct.new $outer
        #|        (struct.new $inner (i32.const 42))))
        #|    (struct.get $inner 0
        #|      (struct.get $outer 0
        #|        (local.get $outer-local))))
        #|  (func (result i32)
        #|    (struct.get $inner 0
        #|      (struct.get $outer 0
        #|        (struct.new $outer (global.get $inner-global))))))
        #|,
      ),
      ["precompute-propagate"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected nested immutable aggregate folds, got \{err}")
  }
  let local_read = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let global_read = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(local_read.contains("I32(42)"), msg=local_read)
  assert_false(local_read.contains("struct.get"), msg=local_read)
  assert_true(global_read.contains("I32(84)"), msg=global_read)
  assert_false(global_read.contains("struct.get"), msg=global_read)
}

///|
test "precompute-propagate emits ref.func from nested immutable reads" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (type $inner (struct (field funcref)))
        #|  (type $outer (struct (field (ref $inner))))
        #|  (type $target-type (func))
        #|  (type $sink-type (func (param funcref)))
        #|  (elem declare func $target)
        #|  (func $target (type $target-type))
        #|  (func $sink (type $sink-type) (param funcref))
        #|  (func
        #|    (local $outer-local (ref null $outer))
        #|    (local.set $outer-local
        #|      (struct.new $outer
        #|        (struct.new $inner (ref.func $target))))
        #|    (call $sink
        #|      (struct.get $inner 0
        #|        (struct.get $outer 0
        #|          (local.get $outer-local))))))
        #|,
      ),
      ["precompute-propagate"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected nested ref.func aggregate fold, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("ref.func"), msg=pretty)
  assert_false(pretty.contains("struct.get"), msg=pretty)
}

///|
test "precompute recursively folds select conditions through deterministic parents" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (param i32) (result i32)
        #|    (i32.eqz
        #|      (select
        #|        (i32.const 0)
        #|        (i32.const 10)
        #|        (i32.eqz
        #|          (select
        #|            (i32.const 0)
        #|            (i32.const 20)
        #|            (local.get 0)))))))
        #|,
      ),
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected recursive select-condition fold, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("select"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(pretty.contains("I32(0)"), msg=pretty)
  assert_false(pretty.contains("i32.eqz"), msg=pretty)
}

///|
test "precompute folds returned integer unary rotate and conversion values" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (result i32) i32.const 8 i32.clz)
        #|  (func (result i32) i32.const 1 i32.const 3 i32.rotl)
        #|  (func (result i64) i32.const -1 i64.extend_i32_u))
        #|,
      ),
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected returned integer folds, got \{err}")
  }
  let clz = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let rotl = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let extended = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(clz.contains("I32(28)"), msg=clz)
  assert_false(clz.contains("i32.clz"), msg=clz)
  assert_true(rotl.contains("I32(8)"), msg=rotl)
  assert_false(rotl.contains("i32.rotl"), msg=rotl)
  assert_true(extended.contains("I64(4294967295)"), msg=extended)
  assert_false(extended.contains("i64.extend_i32_u"), msg=extended)
}

///|
test "precompute folds deterministic SIMD constants but preserves relaxed SIMD" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (result v128)
        #|    (f32x4.max
        #|      (v128.const f32x4 5 6 7 8)
        #|      (v128.const f32x4 9 3 1 0)))
        #|  (func (result v128)
        #|    (i32x4.splat (i32.const 0)))
        #|  (func (result v128)
        #|    (f32x4.relaxed_max
        #|      (v128.const f32x4 1 2 3 4)
        #|      (v128.const f32x4 5 6 7 8))))
        #|,
      ),
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected deterministic SIMD precompute, got \{err}")
  }
  let max = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let splat = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let relaxed = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(max.contains("v128.const") || max.contains("V128Const"), msg=max)
  assert_false(max.contains("f32x4.max") || max.contains("F32x4Max"), msg=max)
  assert_true(
    splat.contains("v128.const") || splat.contains("V128Const"),
    msg=splat,
  )
  assert_false(
    splat.contains("i32x4.splat") || splat.contains("I32x4Splat"),
    msg=splat,
  )
  assert_true(
    relaxed.contains("relaxed_max") || relaxed.contains("RelaxedMax"),
    msg=relaxed,
  )
}

///|
test "precompute folds returned floating unary min and copysign values" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (result f64) f64.const 9 f64.sqrt)
        #|  (func (result f32) f32.const 1.5 f32.const 2.5 f32.min)
        #|  (func (result f64) f64.const 4 f64.const -1 f64.copysign))
        #|,
      ),
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected returned floating folds, got \{err}")
  }
  let sqrt = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let min = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let copysign = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(sqrt.contains("F64(3"), msg=sqrt)
  assert_false(sqrt.contains("f64.sqrt"), msg=sqrt)
  assert_true(min.contains("F32(1.5"), msg=min)
  assert_false(min.contains("f32.min"), msg=min)
  assert_true(copysign.contains("F64(-4"), msg=copysign)
  assert_false(copysign.contains("f64.copysign"), msg=copysign)
}

///|
test "precompute-propagate reads immutable fresh aggregates through locals" {
  let struct_type = @lib.TypeIdx::new(0U)
  let array_type = @lib.TypeIdx::new(1U)
  let func_type = @lib.TypeIdx::new(2U)
  let nullable_struct = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(struct_type)),
  )
  let nullable_array = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(array_type)),
  )
  let array_allocation = fn() {
    [
      @lib.Instruction::i32_const(@lib.I32(10)),
      @lib.Instruction::i32_const(@lib.I32(20)),
      @lib.Instruction::i32_const(@lib.I32(30)),
      @lib.Instruction::array_new_fixed(array_type, @lib.U32(3U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    ]
  }
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::const_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::const_(),
              ),
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([func_type, func_type, func_type, func_type, func_type]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([nullable_struct]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(42)),
            @lib.Instruction::struct_new(struct_type),
            @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::struct_get(struct_type, @lib.U32(0U)),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([nullable_array]),
          @lib.Expr::new(
            array_allocation() +
            [
              @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
              @lib.Instruction::i32_const(@lib.I32(2)),
              @lib.Instruction::array_get(array_type),
            ],
          ),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([nullable_array]),
          @lib.Expr::new(
            array_allocation() +
            [
              @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
              @lib.Instruction::array_len(),
            ],
          ),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([nullable_struct, nullable_struct]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::struct_new(struct_type),
            @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::ref_eq(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::struct_new(struct_type),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::struct_new(struct_type),
            @lib.Instruction::ref_eq(),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["precompute-propagate"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected immutable local aggregate propagation, got \{err}")
  }
  let struct_get = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let array_get = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let array_len = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let equal = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  let unequal = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  assert_true(struct_get.contains("I32(42)"), msg=struct_get)
  assert_false(struct_get.contains("struct.get"), msg=struct_get)
  assert_true(array_get.contains("I32(30)"), msg=array_get)
  assert_false(array_get.contains("array.get"), msg=array_get)
  assert_true(array_len.contains("I32(3)"), msg=array_len)
  assert_false(array_len.contains("array.len"), msg=array_len)
  assert_true(equal.contains("I32(1)"), msg=equal)
  assert_false(equal.contains("ref.eq"), msg=equal)
  assert_true(unequal.contains("I32(0)"), msg=unequal)
  assert_false(unequal.contains("ref.eq"), msg=unequal)
}

///|
test "precompute-propagate folds array lengths through local tee aliases" {
  let array_type = @lib.TypeIdx::new(0U)
  let func_type = @lib.TypeIdx::new(1U)
  let nullable_array = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::new(array_type)),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::var_(),
              ),
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([nullable_array, nullable_array]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::array_new_default(array_type),
            @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
            @lib.Instruction::array_len(),
          ]),
        ),
      ]),
    )
  let pretty = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected array tee alias propagation, got \{err}")
  }
  assert_true(pretty.contains("I32(3)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("array.len"), msg=pretty)
}

///|
test "precompute-propagate substitutes string constants through locals" {
  let pretty = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (result stringref)
        #|    (local $value stringref)
        #|    (local.set $value (string.const "hello"))
        #|    (local.get $value)))
        #|,
      ),
      ["precompute-propagate"],
    ) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected string local propagation, got \{err}")
  }
  assert_false(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("string.const"), msg=pretty)
}

///|
test "precompute-propagate folds local tee allocation identity" {
  let pretty = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (type $s (struct))
        #|  (func (result i32)
        #|    (local $x (ref null $s))
        #|    (local $result i32)
        #|    (local.set $result
        #|      (ref.eq
        #|        (local.tee $x (struct.new $s))
        #|        (local.get $x)))
        #|    (local.get $result)))
        #|,
      ),
      ["precompute-propagate"],
    ) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected local tee identity propagation, got \{err}")
  }
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("ref.eq"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_false(pretty.contains("local.get"), msg=pretty)
}

///|
test "precompute folds fresh immutable array lengths and reads" {
  let array_type = @lib.TypeIdx::new(0U)
  let func_type = @lib.TypeIdx::new(1U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::const_(),
              ),
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([
        func_type, func_type, func_type, func_type, func_type, func_type, func_type,
        func_type, func_type,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(42)),
            @lib.Instruction::array_new_fixed(array_type, @lib.U32(1U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::array_get(array_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::array_new_default(array_type),
            @lib.Instruction::array_len(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::i32_const(@lib.I32(-1)),
            @lib.Instruction::array_new(array_type),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::array_get(array_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::i32_const(@lib.I32(-1)),
            @lib.Instruction::array_new(array_type),
            @lib.Instruction::array_len(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(-1)),
            @lib.Instruction::array_new_default(array_type),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::array_get(array_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::array_new_fixed(array_type, @lib.U32(1U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::array_get(array_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::i32_const(@lib.I32(44739241)),
            @lib.Instruction::array_new(array_type),
            @lib.Instruction::array_len(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::i32_const(@lib.I32(44739242)),
            @lib.Instruction::array_new(array_type),
            @lib.Instruction::array_len(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::i32_const(@lib.I32(44739242)),
            @lib.Instruction::array_new(array_type),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::array_get(array_type),
          ]),
        ),
      ]),
    )
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected immutable array folds, got \{err}")
  }
  let get = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let len = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(get.contains("I32(42)"), msg="\{get}\ntrace=\{trace}")
  assert_false(get.contains("array.get"), msg="\{get}\ntrace=\{trace}")
  assert_false(get.contains("array.new_fixed"), msg=get)
  assert_true(len.contains("I32(7)"), msg=len)
  assert_false(len.contains("array.len"), msg=len)
  assert_false(len.contains("array.new_default"), msg=len)
  let negative_get = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let negative_len = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  let negative_default = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  let fixed_oob = optimized.pretty_print_func(@lib.FuncIdx::new(5U))
  assert_true(
    negative_get.contains("array.new") && negative_get.contains("array.get"),
    msg=negative_get,
  )
  assert_true(
    negative_len.contains("array.new") && negative_len.contains("array.len"),
    msg=negative_len,
  )
  assert_true(
    negative_default.contains("array.new_default") &&
    negative_default.contains("array.get"),
    msg=negative_default,
  )
  assert_true(fixed_oob.contains("array.get"), msg=fixed_oob)
  let below_limit = optimized.pretty_print_func(@lib.FuncIdx::new(6U))
  let at_limit_len = optimized.pretty_print_func(@lib.FuncIdx::new(7U))
  let at_limit_get = optimized.pretty_print_func(@lib.FuncIdx::new(8U))
  assert_true(below_limit.contains("I32(44739241)"), msg=below_limit)
  assert_false(below_limit.contains("array.len"), msg=below_limit)
  assert_true(
    at_limit_len.contains("array.new") && at_limit_len.contains("array.len"),
    msg=at_limit_len,
  )
  assert_true(
    at_limit_get.contains("array.new") && at_limit_get.contains("array.get"),
    msg=at_limit_get,
  )
}

///|
test "precompute family keeps local writes while exposing exact parent values" {
  for pass_name in ["precompute", "precompute-propagate"] {
    let pretty = match
      pass_test_run_pipeline(
        (
          #|(module
          #|  (func (result i32) (local i32)
          #|    i32.const 1
          #|    local.tee 0
          #|    i32.const 2
          #|    i32.add))
          #|,
        ),
        [pass_name],
      ) {
      Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
      Err(err) =>
        fail("expected \{pass_name} effect-preserving fold, got \{err}")
    }
    assert_true(pretty.contains("local.set"), msg="\{pass_name}: \{pretty}")
    assert_true(pretty.contains("I32(3)"), msg="\{pass_name}: \{pretty}")
    assert_false(pretty.contains("i32.add"), msg="\{pass_name}: \{pretty}")
  }
}

///|
test "precompute family preserves multiple ordered local writes while folding parent" {
  for pass_name in ["precompute", "precompute-propagate"] {
    let pretty = match
      pass_test_run_pipeline(
        (
          #|(module
          #|  (func (result i32) (local i32)
          #|    i32.const 10
          #|    local.tee 0
          #|    i32.const 20
          #|    local.tee 0
          #|    i32.add))
          #|,
        ),
        [pass_name],
      ) {
      Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
      Err(err) =>
        fail("expected \{pass_name} ordered multi-write fold, got \{err}")
    }
    assert_true(pretty.contains("I32(30)"), msg="\{pass_name}: \{pretty}")
    assert_false(pretty.contains("i32.add"), msg="\{pass_name}: \{pretty}")
    assert_true(pretty.contains("I32(10)"), msg="\{pass_name}: \{pretty}")
    assert_true(pretty.contains("I32(20)"), msg="\{pass_name}: \{pretty}")
    assert_true(pretty.contains("local.set"), msg="\{pass_name}: \{pretty}")
  }
}

///|
test "precompute reads a local written earlier in the same expression" {
  for pass_name in ["precompute", "precompute-propagate"] {
    let pretty = match
      pass_test_run_pipeline(
        (
          #|(module
          #|  (func (result i32) (local i32)
          #|    i32.const 10
          #|    local.tee 0
          #|    local.get 0
          #|    i32.add))
          #|,
        ),
        [pass_name],
      ) {
      Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
      Err(err) => fail("expected \{pass_name} local-flow fold, got \{err}")
    }
    assert_true(pretty.contains("local.set"), msg="\{pass_name}: \{pretty}")
    assert_true(pretty.contains("I32(20)"), msg="\{pass_name}: \{pretty}")
    assert_false(pretty.contains("i32.add"), msg="\{pass_name}: \{pretty}")
  }
}

///|
test "precompute-propagate uses the default local before a later tee" {
  let source =
    #|(module
    #|  (func (result i32) (local i32)
    #|    local.get 0
    #|    i32.const 10
    #|    local.tee 0
    #|    i32.add))
    #|
  let plain = match pass_test_run_pipeline(source, ["precompute"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected plain precompute boundary success, got \{err}")
  }
  let propagated = match
    pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected propagating local default fold, got \{err}")
  }
  assert_true(plain.contains("i32.add"), msg=plain)
  assert_true(propagated.contains("local.set"), msg=propagated)
  assert_true(propagated.contains("I32(10)"), msg=propagated)
  assert_false(propagated.contains("i32.add"), msg=propagated)
}

///|
test "precompute family preserves nested local and global writes while folding parent" {
  for pass_name in ["precompute", "precompute-propagate"] {
    let pretty = match
      pass_test_run_pipeline(
        (
          #|(module
          #|  (global (mut i32) (i32.const 10))
          #|  (func (result i32) (local i32)
          #|    block (result i32)
          #|      i32.const 10
          #|      local.set 0
          #|      i32.const 20
          #|    end
          #|    block (result i32)
          #|      i32.const 30
          #|      global.set 0
          #|      i32.const 40
          #|    end
          #|    i32.add))
          #|,
        ),
        [pass_name],
      ) {
      Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
      Err(err) => fail("expected \{pass_name} nested effect fold, got \{err}")
    }
    assert_true(pretty.contains("local.set"), msg="\{pass_name}: \{pretty}")
    assert_true(pretty.contains("global.set"), msg="\{pass_name}: \{pretty}")
    assert_true(pretty.contains("I32(60)"), msg="\{pass_name}: \{pretty}")
    assert_false(pretty.contains("i32.add"), msg="\{pass_name}: \{pretty}")
    assert_true(pretty.contains("I32(10)"), msg="\{pass_name}: \{pretty}")
    assert_true(pretty.contains("I32(30)"), msg="\{pass_name}: \{pretty}")
  }
}

///|
test "precompute folds floating nearest signed zero and saturating conversions" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (result i64)
        #|    f64.const -0.1
        #|    f64.nearest
        #|    i64.reinterpret_f64)
        #|  (func (result f64) f64.const 2.5 f64.nearest)
        #|  (func (result i32) f64.const 1e40 i32.trunc_sat_f64_s)
        #|  (func (result i64) f64.const 42.75 i64.trunc_f64_s)
        #|  (func (result i64) f64.const 9223372036854775808 i64.trunc_f64_u)
        #|  (func (result i64) f64.const 18446744073709549568 i64.trunc_f64_u))
        #|,
      ),
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected floating edge folds, got \{err}")
  }
  let negative_zero = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let ties_even = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let saturated = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let truncated = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  let unsigned_high_bit = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  let unsigned_high = optimized.pretty_print_func(@lib.FuncIdx::new(5U))
  assert_true(
    negative_zero.contains("I64(-9223372036854775808)"),
    msg=negative_zero,
  )
  assert_false(negative_zero.contains("f64.nearest"), msg=negative_zero)
  assert_true(ties_even.contains("F64(2"), msg=ties_even)
  assert_false(ties_even.contains("f64.nearest"), msg=ties_even)
  assert_true(saturated.contains("I32(2147483647)"), msg=saturated)
  assert_false(saturated.contains("trunc_sat"), msg=saturated)
  assert_true(truncated.contains("I64(42)"), msg=truncated)
  assert_false(truncated.contains("i64.trunc_f64_s"), msg=truncated)
  assert_true(
    unsigned_high_bit.contains("I64(-9223372036854775808)"),
    msg=unsigned_high_bit,
  )
  assert_true(unsigned_high.contains("I64(-2048)"), msg=unsigned_high)
  assert_false(
    unsigned_high_bit.contains("i64.trunc_f64_u"),
    msg=unsigned_high_bit,
  )
  assert_false(unsigned_high.contains("i64.trunc_f64_u"), msg=unsigned_high)
}

///|
test "precompute matches Binaryen floating NaN infinity and subnormal folds" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (result i32)
        #|    f32.const nan
        #|    f32.ceil
        #|    i32.reinterpret_f32)
        #|  (func (result i32)
        #|    f32.const -1
        #|    f32.sqrt
        #|    i32.reinterpret_f32)
        #|  (func (result i32)
        #|    f32.const nan
        #|    f32.const 1
        #|    f32.min
        #|    i32.reinterpret_f32)
        #|  (func (result i64)
        #|    f64.const inf
        #|    f64.ceil
        #|    i64.reinterpret_f64)
        #|  (func (result i32)
        #|    f32.const -1.401298464324817e-45
        #|    f32.nearest
        #|    i32.reinterpret_f32)
        #|  (func (result i32)
        #|    f64.const nan
        #|    f32.demote_f64
        #|    i32.reinterpret_f32)
        #|  (func (result i64)
        #|    f32.const nan
        #|    f64.promote_f32
        #|    i64.reinterpret_f64)
        #|  (func (result i32)
        #|    f32.const 0
        #|    f32.const 0
        #|    f32.div
        #|    i32.reinterpret_f32)
        #|  (func (result i64)
        #|    f64.const 0
        #|    f64.const 0
        #|    f64.div
        #|    i64.reinterpret_f64)
        #|  (func (result i32)
        #|    f32.const -0
        #|    f32.const 0
        #|    f32.max
        #|    i32.reinterpret_f32)
        #|  (func (result i64)
        #|    f64.const -0
        #|    f64.const 0
        #|    f64.max
        #|    i64.reinterpret_f64))
        #|,
      ),
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected floating edge folds, got \{err}")
  }
  let nan_ceil = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let negative_sqrt = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let nan_min = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let infinity = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  let subnormal = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  let demoted_nan = optimized.pretty_print_func(@lib.FuncIdx::new(5U))
  let promoted_nan = optimized.pretty_print_func(@lib.FuncIdx::new(6U))
  let f32_arithmetic_nan = optimized.pretty_print_func(@lib.FuncIdx::new(7U))
  let f64_arithmetic_nan = optimized.pretty_print_func(@lib.FuncIdx::new(8U))
  let f32_max_zero = optimized.pretty_print_func(@lib.FuncIdx::new(9U))
  let f64_max_zero = optimized.pretty_print_func(@lib.FuncIdx::new(10U))
  assert_true(nan_ceil.contains("I32(2143289344)"), msg=nan_ceil)
  assert_true(negative_sqrt.contains("I32(2143289344)"), msg=negative_sqrt)
  assert_true(nan_min.contains("I32(2143289344)"), msg=nan_min)
  assert_true(infinity.contains("I64(9218868437227405312)"), msg=infinity)
  assert_true(subnormal.contains("I32(-2147483648)"), msg=subnormal)
  assert_true(demoted_nan.contains("I32(2143289344)"), msg=demoted_nan)
  assert_true(
    promoted_nan.contains("I64(9221120237041090560)"),
    msg=promoted_nan,
  )
  assert_true(
    f32_arithmetic_nan.contains("I32(2143289344)"),
    msg=f32_arithmetic_nan,
  )
  assert_true(
    f64_arithmetic_nan.contains("I64(9221120237041090560)"),
    msg=f64_arithmetic_nan,
  )
  assert_true(f32_max_zero.contains("I32(0)"), msg=f32_max_zero)
  assert_true(f64_max_zero.contains("I64(0)"), msg=f64_max_zero)
  for
    pretty in [
      nan_ceil, negative_sqrt, nan_min, infinity, subnormal, demoted_nan, promoted_nan,
      f32_arithmetic_nan, f64_arithmetic_nan, f32_max_zero, f64_max_zero,
    ] {
    assert_false(pretty.contains("f32.ceil"), msg=pretty)
    assert_false(pretty.contains("f32.sqrt"), msg=pretty)
    assert_false(pretty.contains("f32.min"), msg=pretty)
    assert_false(pretty.contains("f64.ceil"), msg=pretty)
    assert_false(pretty.contains("f32.nearest"), msg=pretty)
    assert_false(pretty.contains("f32.demote_f64"), msg=pretty)
    assert_false(pretty.contains("f64.promote_f32"), msg=pretty)
    assert_false(pretty.contains("f32.div"), msg=pretty)
    assert_false(pretty.contains("f64.div"), msg=pretty)
    assert_false(pretty.contains("f32.max"), msg=pretty)
    assert_false(pretty.contains("f64.max"), msg=pretty)
  }
}

///|
test "precompute repeatedly evaluates unary parents through select arms" {
  let pretty = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (param i32) (result i32)
        #|    i32.const -3
        #|    i32.const -2
        #|    local.get 0
        #|    select
        #|    i32.const 3
        #|    i32.add
        #|    i32.eqz))
        #|,
      ),
      ["precompute"],
      options=HotPipelineOptions::new(optimize_level=2),
    ) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected multi-parent select fold, got \{err}")
  }
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(pretty.contains("I32(0)"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
  assert_false(pretty.contains("i32.eqz"), msg=pretty)
}

///|
test "precompute folds default and packed fresh struct reads" {
  let struct_type = @lib.TypeIdx::new(0U)
  let packed_type = @lib.TypeIdx::new(1U)
  let i32_func = @lib.TypeIdx::new(2U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::const_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::pack_type(@lib.PackType::i8()),
                @lib.Mut::const_(),
              ),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([i32_func, i32_func]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::struct_new_default(struct_type),
            @lib.Instruction::struct_get(struct_type, @lib.U32(0U)),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(255)),
            @lib.Instruction::struct_new(packed_type),
            @lib.Instruction::struct_get_s(packed_type, @lib.U32(0U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["precompute"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected fresh struct field folds, got \{err}")
  }
  let defaulted = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let packed = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(defaulted.contains("I32(0)"), msg=defaulted)
  assert_false(defaulted.contains("struct.get"), msg=defaulted)
  assert_true(packed.contains("I32(-1)"), msg=packed)
  assert_false(packed.contains("struct.get_s"), msg=packed)
}
