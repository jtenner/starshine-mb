///|
test "run_hot_pipeline applies optimize preset through the hot pass manager" {
  let input = pass_test_module_from_wat(
    "(module (func (export \"run\") (result i32) nop i32.const 7))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize"]) {
    Ok(mod) => mod
    Err(err) => fail("expected optimize pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected optimized module to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("nop"))
  assert_true(pretty.contains("i32.const"))
  assert_true(pretty.contains("I32(7)"))
}

///|
test "public O4z optimize preset executes the late RSE vacuum DAEO neighborhood" {
  let input = pass_test_module_from_wat(
    "(module (func (export \"run\") (result i32) nop i32.const 7))",
  )
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(
        optimize_level=4,
        shrink_level=4,
        trace=Some(fn(line) { trace.push(line) }),
      ),
      ["optimize"],
    ) {
    Ok(mod) => mod
    Err(err) => fail("expected O4z optimize pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected O4z optimized module to validate, got \{err}")
  }
  let mut rse_start = -1
  let mut late_vacuum_start = -1
  let mut dae_start = -1
  let mut inlining_start = -1
  for idx, line in trace {
    if line.starts_with("pass[redundant-set-elimination]:") && dae_start < 0 {
      rse_start = idx
    } else if line.starts_with("pass[vacuum]:") &&
      rse_start >= 0 &&
      dae_start < 0 {
      late_vacuum_start = idx
    } else if line == "pass[dae-optimizing]:start" && dae_start < 0 {
      dae_start = idx
    } else if line == "pass[inlining-optimizing]:start" && inlining_start < 0 {
      inlining_start = idx
    }
  }
  assert_true(rse_start >= 0, msg="expected public preset RSE execution")
  assert_true(
    late_vacuum_start > rse_start,
    msg="expected final vacuum after RSE before DAEO",
  )
  assert_true(
    dae_start > late_vacuum_start,
    msg="expected DAEO after the final function cleanup",
  )
  assert_true(
    inlining_start > dae_start,
    msg="expected inlining-optimizing after DAEO",
  )
}

///|
test "vacuum skips O4z raw pass until self-opt CLI flag parsing is safe" {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      "(module (func i32.const 1 drop))",
      ["vacuum"],
      options=HotPipelineOptions::new(
        optimize_level=4,
        shrink_level=1,
        trace=Some(fn(line) { trace.push(line) }),
      ),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected O4z vacuum skip success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[vacuum]:skip-raw reason=o4z-vacuum-noop")
    }),
  )
}

///|
test "vacuum removes dropped pure scalar expressions" {
  let input = pass_test_module_from_wat(
    "(module (func (local i32) (drop (i32.add (i32.const 1) (i32.const 2))) (local.set 0 (i32.const 4))))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) => fail("expected vacuum pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected vacuumed module to validate, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      ])
    other =>
      fail(
        "expected single vacuumed function output, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum preserves dropped zero-divisor traps after unsigned canonicalization" {
  let input = "(module (type (func (result i32 i64))) (func block (type 0) i32.const 1 i32.const 0 i32.div_s drop i32.const 7 i64.const 9 end drop drop))"
  let optimized = match
    pass_test_run_pipeline(input, ["optimize-instructions", "vacuum"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected trapping vacuum pipeline success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.div_u"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
}

///|
test "vacuum removing empty block preserves hot label ownership" {
  let func = pass_test_lift_first_func("(module (func (block)))")
  let ctx = HotPassContext::new(
    @ir.HotPassDescriptor::new("vacuum"),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_msg) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected vacuum empty-block success, got \{err}")
  }
  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected vacuum empty-block label owners to verify, got \{err}")
  }
}

///|
test "vacuum empty-then inversion preserves hot label ownership" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (if (i32.eqz (local.get 0)) (then) (else (drop (i32.const 9))))))",
  )
  let ctx = HotPassContext::new(
    @ir.HotPassDescriptor::new("vacuum"),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_msg) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected vacuum empty-then inversion success, got \{err}")
  }
  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected vacuum empty-then inversion label owners to verify, got \{err}",
      )
  }
}

///|
test "vacuum removes pure drops in root local set call hazards" {
  let input =
    #|(module
    #|  (import "env" "tick" (func))
    #|  (func (local i32)
    #|    (drop (i32.add (i32.const 1) (i32.const 2)))
    #|    (call 0)
    #|    (local.set 0 (i32.const 4))
    #|  )
    #|)
  let optimized = match pass_test_run_pipeline(input, ["vacuum"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected root-hazard vacuum pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected root-hazard vacuum output to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("i32.add"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
}

///|
test "vacuum removes raw nontrapping int division and sign extends in call hazards" {
  let input =
    #|(module
    #|  (import "env" "tick" (func))
    #|  (func (local i32)
    #|    (drop (i32.div_s (i32.const 84) (i32.const 3)))
    #|    (drop (i64.rem_u (i64.const 99) (i64.const 5)))
    #|    (drop (i32.extend8_s (i32.const 127)))
    #|    (call 0)
    #|    (local.set 0 (i32.const 4))
    #|  )
    #|)
  let optimized = match pass_test_run_pipeline(input, ["vacuum"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nontrapping raw vacuum fixture success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected nontrapping raw vacuum output to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("div_s"), msg=pretty)
  assert_false(pretty.contains("rem_u"), msg=pretty)
  assert_false(pretty.contains("extend8_s"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
}

///|
test "vacuum preserves allocation barrier visit roots while cleaning debris" {
  let input =
    #|(module
    #|  (import "rt" "alloc" (func $alloc (param i32) (result i32)))
    #|  (import "rt" "barrier" (func $barrier (param i32 i32)))
    #|  (import "rt" "visit" (func $visit (param i32)))
    #|  (memory 1)
    #|  (func (param $size i32) (local $obj i32) (local $field i32)
    #|    (drop (i32.const 11))
    #|    (local.set $obj (call $alloc (local.get $size)))
    #|    (drop (i32.add (i32.const 1) (i32.const 2)))
    #|    (local.set $field (call $alloc (i32.const 4)))
    #|    (i32.store offset=8 (local.get $obj) (local.get $field))
    #|    (call $barrier (local.get $obj) (local.get $field))
    #|    (drop (i32.const 0))
    #|    (call $visit (local.get $obj))
    #|  )
    #|)
  let optimized = match pass_test_run_pipeline(input, ["vacuum"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected allocation/barrier vacuum fixture success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected allocation/barrier vacuum output to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
  assert_true(pretty.contains("i32.store"), msg=pretty)
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("call (Func 1)"), msg=pretty)
  assert_true(pretty.contains("call (Func 2)"), msg=pretty)
}

///|
test "vacuum removes dropped nontrapping local-read expressions" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (local i32) (drop (i32.add (local.get 0) (i32.const 1))) (local.set 1 (i32.const 4))))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) => fail("expected local-read vacuum pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected local-read vacuumed module to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
}

///|
test "vacuum removes nested if branch pure debris inside value expression" {
  let input =
    #|(module
    #|  (func (param i32) (result i32)
    #|    (i32.add
    #|      (if (result i32)
    #|        (local.get 0)
    #|        (then
    #|          (drop (i32.const 0))
    #|          (i32.const 1)
    #|        )
    #|        (else
    #|          (nop)
    #|          (i32.const 2)
    #|        )
    #|      )
    #|      (i32.const 3)
    #|    )
    #|  )
    #|)
  let optimized = match pass_test_run_pipeline(input, ["vacuum"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected nested-if vacuum fixture success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected nested-if vacuum output to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("nop"), msg=pretty)
}

///|
fn vacuum_test_make_large_nested_value_debris() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  out.write_string("  (func (param i32) (result i32) (local i32)\n")
  let mut i = 0
  while i < 1100 {
    out.write_string("    i32.const ")
    out.write_string((i & 255).to_string())
    out.write_string("\n    local.set 1\n")
    i = i + 1
  }
  let tail =
    #|    (i32.add
    #|      (if (result i32)
    #|        (local.get 0)
    #|        (then
    #|          (drop (i32.const 0))
    #|          (i32.const 1)
    #|        )
    #|        (else
    #|          (nop)
    #|          (i32.const 2)
    #|        )
    #|      )
    #|      (i32.const 3)
    #|    )
    #|  )
    #|)
    #|,
  out.write_string(tail)
  out.to_string()
}

///|
test "vacuum removes nested value-expression debris in large functions" {
  let optimized = match
    pass_test_run_pipeline(vacuum_test_make_large_nested_value_debris(), [
      "vacuum",
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected large nested vacuum fixture success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected large nested vacuum output to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("nop"), msg=pretty)
}

///|
test "vacuum skips branchy structured writes" {
  let input =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if
    #|      i32.const 0
    #|      drop
    #|      i32.const 1
    #|      local.set 1
    #|      local.get 0
    #|      br_if 0
    #|    end))
  let optimized = match pass_test_run_pipeline(input, ["vacuum"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected branchy structured vacuum fixture success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected branchy structured vacuum output to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
}

///|
test "vacuum raw-cleans root stack/local-set call hazards" {
  let trace : Array[String] = []
  let input =
    #|(module
    #|  (func $alloc (param i32 i32) (result i32)
    #|    local.get 0)
    #|  (func (param i32 i32) (local i32)
    #|    local.get 0
    #|    i32.const 2
    #|    call $alloc
    #|    local.set 2
    #|    local.get 2
    #|    local.get 1
    #|    call $alloc
    #|    drop
    #|    i32.const 1
    #|    drop))
    #|
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["vacuum"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected root stack/local-set vacuum hazard success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected root stack/local-set output to validate, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[vacuum]:skip-raw reason=raw-vacuum-preclean")
    }),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_false(pretty.contains("I32(1)"), msg=pretty)
}

///|
test "vacuum clears local-only void function bodies" {
  let input =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    (local.set 1 (i32.const 101))
    #|    (drop (local.get 1))
    #|    (drop (local.tee 1 (i32.const 7)))
    #|    (local.set 2 (i32.const 0))
    #|    (if
    #|      (local.get 2)
    #|      (then
    #|        (local.set 1 (i32.const 1))
    #|      )
    #|      (else
    #|        (local.set 1 (i32.const 2))
    #|      )
    #|    )
    #|    (if
    #|      (local.get 1)
    #|      (then
    #|        (local.set 1 (i32.const 7))
    #|      )
    #|    )
    #|  )
    #|)
  let optimized = match pass_test_run_pipeline(input, ["vacuum"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-only vacuum fixture success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected local-only vacuum output to validate, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [@lib.Instruction::nop()])
    other =>
      fail(
        "expected local-only vacuum body to canonicalize to one nop, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum clears branchy local-only void function bodies" {
  let input =
    #|(module
    #|  (func (param i32) (local i32 i32)
    #|    (local.set 1 (i32.const 1))
    #|    (block
    #|      (local.get 0)
    #|      (br_if 0)
    #|      (local.set 1 (i32.const 9))
    #|    )
    #|    (drop
    #|      (if (result i32)
    #|        (local.get 0)
    #|        (then
    #|          (local.set 2 (i32.const 20))
    #|          (i32.const 2)
    #|        )
    #|        (else
    #|          (local.set 2 (i32.const 30))
    #|          (i32.const 3)
    #|        )
    #|      )
    #|    )
    #|    (drop (local.tee 1 (i32.const 7)))
    #|    (return)
    #|  )
    #|)
  let optimized = match pass_test_run_pipeline(input, ["vacuum"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected branchy local-only vacuum fixture success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected branchy local-only vacuum output to validate, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [@lib.Instruction::nop()])
    other =>
      fail(
        "expected branchy local-only vacuum body to canonicalize to one nop, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum flips empty then with live else" {
  let input =
    #|(module
    #|  (func (param i32) (local i32)
    #|    (if
    #|      (i32.eqz (local.get 0))
    #|      (then)
    #|      (else
    #|        (local.set 1 (i32.const 1))
    #|      )
    #|    )
    #|  )
    #|)
  let optimized = match pass_test_run_pipeline(input, ["vacuum"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected empty-then vacuum fixture success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected empty-then vacuum output to validate, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::i32_eqz(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          ],
          None,
        ),
      ])
    other =>
      fail(
        "expected single empty-then vacuum function output, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum raw-flips empty then with live else in guarded lowered functions" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "side" (func $side (param i32)))
      #|  (func (param i32) (local i32)
      #|    nop nop nop nop nop nop nop nop
      #|    nop nop nop nop nop nop nop nop
      #|    (local.set 1 (local.get 0))
      #|    (block
      #|      (block
      #|        (if (i32.eq (local.get 1) (i32.const 1))
      #|          (then)
      #|          (else
      #|            (if (i32.eq (local.get 1) (i32.const 3))
      #|              (then (call $side (local.get 1)))
      #|              (else unreachable)
      #|            )
      #|          )
      #|        )
      #|      )
      #|      (call $side (local.get 1))
      #|    )
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected raw empty-then vacuum fixture success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected raw empty-then vacuum output to validate, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_eq(),
            @lib.Instruction::i32_eqz(),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_const(@lib.I32(3)),
                @lib.Instruction::i32_eq(),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                  ],
                  Some([@lib.Instruction::unreachable_()]),
                ),
              ],
              None,
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
      ])
    other =>
      fail(
        "expected raw empty-then if to be inverted, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum raw-unwraps single if wrappers that contain unreachable" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "side" (func $side (param i32)))
      #|  (func (param i32) (local i32)
      #|    nop nop nop nop nop nop nop nop
      #|    nop nop nop nop nop nop nop nop
      #|    (local.set 1 (local.get 0))
      #|    (block
      #|      (block
      #|        (if (local.get 1)
      #|          (then
      #|            (call $side (local.get 1))
      #|            (br 2)
      #|          )
      #|          (else unreachable)
      #|        )
      #|      )
      #|      (call $side (local.get 1))
      #|    )
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected raw single-if wrapper vacuum fixture success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected raw single-if wrapper vacuum output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ],
              Some([@lib.Instruction::unreachable_()]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
      ])
    other =>
      fail(
        "expected raw single-if wrapper to be unwrapped and branches rebased, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum raw-unwraps type-indexed empty branchy single-if wrappers that contain unreachable" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $empty (func))
      #|  (import "m" "side" (func $side (param i32)))
      #|  (import "m" "pred" (func $pred (param i32) (result i32)))
      #|  (memory 1)
      #|  (func (param i32 i32) (local i32 i32 i32 i32)
      #|    nop nop nop nop nop nop nop nop
      #|    nop nop nop nop nop nop nop nop
      #|    (block $exit
      #|      (block $after
      #|        (block (type $empty)
      #|          (i32.const 0)
      #|          (i32.const 0)
      #|          (i32.const 2)
      #|          (i32.shl)
      #|          (i32.add)
      #|          (i32.load)
      #|          (local.tee 2)
      #|          (call $pred)
      #|          (local.tee 3)
      #|          (if
      #|            (then
      #|              (if (i32.eq (local.get 0) (i32.const 1))
      #|                (then
      #|                  (call $side (local.get 0))
      #|                  (local.set 2 (local.get 0))
      #|                  (br $after)
      #|                )
      #|                (else
      #|                  (call $side (local.get 1))
      #|                  (local.set 3 (local.get 1))
      #|                  (br $exit)
      #|                )
      #|              )
      #|              unreachable
      #|            )
      #|            (else
      #|              (block $made
      #|                (block $skip
      #|                  (call $side (local.get 0))
      #|                  (if (local.get 1)
      #|                    (then (call $side (local.get 1)))
      #|                    (else
      #|                      (local.set 4 (local.get 0))
      #|                      (br $skip)
      #|                    )
      #|                  )
      #|                  (br $made)
      #|                )
      #|                (call $side (local.get 4))
      #|                (return)
      #|              )
      #|            )
      #|          )
      #|        )
      #|        (local.set 5 (i32.const 0))
      #|        (br $after)
      #|      )
      #|      (call $side (local.get 2))
      #|    )
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail(
        "expected type-indexed branchy single-if wrapper vacuum fixture success, got \{err}",
      )
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected type-indexed branchy single-if wrapper vacuum output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      match instrs {
        [@lib.Block(_, @lib.Expr(exit_body))] =>
          match exit_body[0] {
            @lib.Block(_, @lib.Expr(after_body)) =>
              match after_body[0] {
                @lib.Block(_, _) =>
                  fail(
                    "expected type-indexed raw branchy single-if wrapper to be unwrapped before the continuation, got \{@debug.to_string(after_body)}",
                  )
                _ => ()
              }
            other =>
              fail(
                "expected outer continuation block after type-indexed branchy single-if unwrap, got \{@debug.to_string(other)}",
              )
          }
        other =>
          fail(
            "expected type-indexed branchy single-if wrapper fixture to keep the outer block skeleton, got \{@debug.to_string(other)}",
          )
      }
    other =>
      fail(
        "expected type-indexed branchy single-if wrapper function body, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum raw-unwraps call-tee if wrappers that contain unreachable" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "tag" (func $tag (param i32) (result i32)))
      #|  (import "m" "side" (func $side (param i32)))
      #|  (func (param i32) (local i32)
      #|    nop nop nop nop nop nop nop nop
      #|    nop nop nop nop nop nop nop nop
      #|    (block
      #|      (block
      #|        (if (local.tee 1 (call $tag (local.get 0)))
      #|          (then
      #|            (call $side (local.get 1))
      #|            (br 2)
      #|          )
      #|          (else unreachable)
      #|        )
      #|      )
      #|      (call $side (local.get 0))
      #|    )
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail(
        "expected raw call-tee if wrapper vacuum fixture success, got \{err}",
      )
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected raw call-tee if wrapper vacuum output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
            @lib.Instruction::if_(
              @lib.BlockType::void_(),
              [
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::call(@lib.FuncIdx::new(1U)),
                @lib.Instruction::br(@lib.LabelIdx::new(1U)),
              ],
              Some([@lib.Instruction::unreachable_()]),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          ]),
        ),
      ])
    other =>
      fail(
        "expected raw call-tee if wrapper to be unwrapped and branches rebased, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum raw-drops empty else arms in lowered void ifs" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (func (param i32) (local i32)
      #|    nop nop nop nop nop nop nop nop
      #|    nop nop nop nop nop nop nop nop
      #|    (local.set 1 (local.get 0))
      #|    (block
      #|      (if (local.get 1)
      #|        (then
      #|          (local.set 1 (i32.const 2))
      #|          (br 0)
      #|        )
      #|        (else nop)
      #|      )
      #|    )
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected raw empty-else vacuum fixture success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected raw empty-else vacuum output to validate, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          ],
          None,
        ),
      ])
    other =>
      fail(
        "expected raw empty-else if to drop else arm, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum collapses constant void if to taken arm" {
  let input =
    #|(module
    #|  (func (local i32)
    #|    (if
    #|      (i32.const 1)
    #|      (then
    #|        (i32.const 7)
    #|        (local.set 0)
    #|      )
    #|      (else
    #|        (i32.const 8)
    #|        (local.set 0)
    #|      )
    #|    )
    #|  )
    #|)
  let optimized = match pass_test_run_pipeline(input, ["vacuum"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected constant-if vacuum fixture success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected constant-if vacuum output to validate, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      ])
    other =>
      fail(
        "expected constant-if vacuum output to keep only taken arm, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum collapses constant void if with nested block-local branch" {
  let input =
    #|(module
    #|  (func
    #|    (if
    #|      (i32.const 1)
    #|      (then
    #|        (block
    #|          (br 0)
    #|        )
    #|      )
    #|      (else)
    #|    )
    #|  )
    #|)
  let optimized = match pass_test_run_pipeline(input, ["vacuum"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nested-branch constant-if vacuum fixture success, got \{err}",
      )
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected nested-branch constant-if vacuum output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
        ),
      ])
    other =>
      fail(
        "expected nested-branch constant-if vacuum output to keep taken block, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn vacuum_test_expected_branch_scaffold_instrs() -> Array[@lib.Instruction] {
  [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
      ]),
    ),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
      ]),
    ),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
    ),
  ]
}

///|
test "vacuum collapses generated branch scaffold constant if" {
  let input =
    #|(module
    #|  (func
    #|    (loop
    #|      (br_if 0 (i32.const 1))
    #|    )
    #|    (block
    #|      (br_if 0 (i32.const 0))
    #|    )
    #|    (if
    #|      (i32.const 1)
    #|      (then
    #|        (block
    #|          (br 0)
    #|        )
    #|      )
    #|      (else
    #|        (nop)
    #|      )
    #|    )
    #|  )
    #|)
  let optimized = match pass_test_run_pipeline(input, ["vacuum"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected generated-scaffold constant-if vacuum success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected generated-scaffold constant-if output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, vacuum_test_expected_branch_scaffold_instrs())
    other =>
      fail(
        "expected generated-scaffold constant-if output to keep loop/block/taken block, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn vacuum_test_make_large_const_if_scaffold() -> String {
  let out = StringBuilder::new()
  out.write_string("(module (func\n")
  for i = 0; i < 2200; i = i + 1 {
    out.write_string("  (drop (i32.const ")
    out.write_string(i.to_string())
    out.write_string("))\n")
  }
  out.write_string(
    (
      #|  (loop (br_if 0 (i32.const 1)))
      #|  (block (br_if 0 (i32.const 0)))
      #|  (if
      #|    (i32.const 1)
      #|    (then (block (br 0)))
      #|    (else (nop)))
      #|))
      #|,
    ),
  )
  out.to_string()
}

///|
test "vacuum collapses large generated branch scaffold constant if" {
  let optimized = match
    pass_test_run_pipeline(vacuum_test_make_large_const_if_scaffold(), [
      "vacuum",
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected large generated-scaffold constant-if vacuum success, got \{err}",
      )
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected large generated-scaffold constant-if output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, vacuum_test_expected_branch_scaffold_instrs())
    other =>
      fail(
        "expected large generated-scaffold constant-if output to keep loop/block/taken block, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum removes empty void blocks" {
  let input = pass_test_module_from_wat(
    "(module (func (local i32) block end i32.const 5 local.set 0))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) => fail("expected vacuum pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected empty-block vacuum output to validate, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::i32_const(@lib.I32(5)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      ])
    other =>
      fail("expected empty block to be removed, got \{@debug.to_string(other)}")
  }
}

///|
test "vacuum unwraps untargeted if-wrapper void blocks" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (local i32) block (if (local.get 0) (then i32.const 7 local.set 1)) end))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) => fail("expected vacuum pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected untargeted block vacuum output to validate, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          ],
          None,
        ),
      ])
    other =>
      fail(
        "expected untargeted if-wrapper block to be unwrapped, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum raw-unwraps singleton call-prefix if blocks with outer branches" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "side" (func $side (param i32)))
      #|  (import "m" "make" (func $make (param i32) (result i32)))
      #|  (func (param i32) (local i32)
      #|    (block
      #|      (block
      #|        (block
      #|          (block
      #|            nop nop nop nop
      #|            (local.set 1 (call $make (local.get 0)))
      #|            nop
      #|            (call $side (local.get 0))
      #|          )
      #|          nop nop
      #|          (if (local.get 1)
      #|            (then
      #|              nop
      #|              (call $side (local.get 1))
      #|              (br 3)
      #|            )
      #|          )
      #|        )
      #|      )
      #|    )
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) => fail("expected vacuum pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected call-prefix wrapper output to validate, got \{err}")
  }
  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.Block(
                  @lib.VoidBlockType,
                  @lib.Expr([@lib.Block(@lib.VoidBlockType, @lib.Expr(body))])
                ),
              ]
            )
          ),
        ]
      )
    ) =>
      @debug.assert_eq(body, [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::br(@lib.LabelIdx::new(2U)),
          ],
          None,
        ),
      ])
    other =>
      fail(
        "expected singleton call-prefix if wrapper to be unwrapped, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum raw-unwraps recursive block-prefix if wrappers" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "side" (func $side (param i32)))
      #|  (import "m" "make" (func $make (param i32) (result i32)))
      #|  (func (param i32) (local i32 i32)
      #|    (block
      #|      (block
      #|        (block
      #|          (block
      #|            (block
      #|              nop nop nop nop nop nop nop nop
      #|              nop nop nop nop nop nop nop nop
      #|              (local.set 1 (call $make (local.get 0)))
      #|              nop
      #|              (call $side (local.get 0))
      #|            )
      #|            nop nop
      #|            (if (i32.eq (call $make (local.get 1)) (i32.const 1))
      #|              (then
      #|                nop
      #|                (call $side (local.get 1))
      #|              )
      #|            )
      #|          )
      #|        )
      #|      )
      #|    )
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected recursive block-prefix vacuum success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected recursive block-prefix vacuum output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::i32_const(@lib.I32::new(1)),
        @lib.Instruction::i32_eq(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ],
          None,
        ),
      ])
    other =>
      fail(
        "expected recursive block-prefix if wrapper to be unwrapped, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum raw-unwraps side-effect if wrapper child blocks" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "side" (func $side (param i32)))
      #|  (import "m" "make" (func $make (param i32) (result i32)))
      #|  (import "m" "pred" (func $pred (param i32) (result i32)))
      #|  (func (param i32) (local i32 i32)
      #|    (block
      #|      (block
      #|        (block
      #|          nop nop nop nop nop nop nop nop
      #|          nop nop nop nop nop nop nop nop
      #|          (call $side (local.get 0))
      #|          (local.set 1 (call $make (local.get 0)))
      #|          (call $side (local.get 1))
      #|          (if (i32.eq (call $pred (local.get 1)) (i32.const 1))
      #|            (then
      #|              (local.set 2 (local.get 1))
      #|              (br 3)
      #|            )
      #|          )
      #|        )
      #|      )
      #|      (call $side (i32.const 7))
      #|    )
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected side-effect child-wrapper vacuum success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected side-effect child-wrapper vacuum output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::call(@lib.FuncIdx::new(1U)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::call(@lib.FuncIdx::new(2U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_eq(),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                  ],
                  None,
                ),
              ]),
            ),
            @lib.Instruction::i32_const(@lib.I32::new(7)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
      ])
    other =>
      fail(
        "expected side-effect child wrapper only to be unwrapped, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum preserves local-set-leading side-effect child wrappers" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "side" (func $side (param i32)))
      #|  (import "m" "make" (func $make (param i32) (result i32)))
      #|  (import "m" "pred" (func $pred (param i32) (result i32)))
      #|  (func (param i32) (local i32 i32)
      #|    (block
      #|      (block
      #|        (block
      #|          nop nop nop nop nop nop nop nop
      #|          nop nop nop nop nop nop nop nop
      #|          (local.set 1 (call $make (local.get 0)))
      #|          (call $side (local.get 1))
      #|          (if (i32.eq (call $pred (local.get 1)) (i32.const 1))
      #|            (then
      #|              (local.set 2 (local.get 1))
      #|              (br 3)
      #|            )
      #|          )
      #|        )
      #|      )
      #|      (call $side (i32.const 7))
      #|    )
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected local-set-leading wrapper vacuum success, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                    @lib.Instruction::call(@lib.FuncIdx::new(2U)),
                    @lib.Instruction::i32_const(@lib.I32::new(1)),
                    @lib.Instruction::i32_eq(),
                    @lib.Instruction::if_(
                      @lib.BlockType::void_(),
                      [
                        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                        @lib.Instruction::br(@lib.LabelIdx::new(3U)),
                      ],
                      None,
                    ),
                  ]),
                ),
              ]),
            ),
            @lib.Instruction::i32_const(@lib.I32::new(7)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
      ])
    other =>
      fail(
        "expected local-set-leading side-effect child wrapper to stay wrapped, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum raw-unwraps branchy local-set-call prefix parent wrappers" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (func $pred (param i32) (result i32) (local.get 0))
      #|  (func $release (param i32) (drop (local.get 0)))
      #|  (func $make (param i32) (result i32) (local.get 0))
      #|  (func $run (export "run")
      #|    (local $x i32)
      #|    (local $tmp i32)
      #|    (block $outer
      #|      (block
      #|        (block
      #|          (block
      #|            (local.set $x (call $make (i32.const 0)))
      #|            (call $release (i32.const 0))
      #|          )
      #|          (if (call $pred (local.tee $tmp (local.get $x)))
      #|            (then
      #|              (nop)
      #|            )
      #|            (else
      #|              (br $outer)
      #|            )
      #|          )
      #|        )
      #|        (nop)
      #|      )
      #|      (unreachable)
      #|    )
      #|    (unreachable)
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected branchy local-set-call prefix vacuum success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected branchy local-set-call prefix vacuum output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs[3] {
        @lib.Func(_, @lib.Expr(instrs)) =>
          match instrs[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) => {
              @debug.assert_eq(outer_body.length(), 2)
              match outer_body[0] {
                @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_if_body)) => {
                  @debug.assert_eq(prefix_if_body.length(), 6)
                  match prefix_if_body[0] {
                    @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) => {
                      @debug.assert_eq(prefix_body.length(), 5)
                      match prefix_body[2] {
                        @lib.LocalSet(@lib.LocalIdx(raw)) =>
                          @debug.assert_eq(raw.reinterpret_as_int(), 0)
                        other =>
                          fail(
                            "expected prefix block local.set fed by a direct call, got \{@debug.to_string(other)}",
                          )
                      }
                    }
                    @lib.Block(_, _) =>
                      fail(
                        "expected Binaryen-shaped single prefix block, got nested extra wrapper",
                      )
                    other =>
                      fail(
                        "expected flattened branchy local-set-call prefix block, got \{@debug.to_string(other)}",
                      )
                  }
                  match prefix_if_body[5] {
                    @lib.If(@lib.VoidBlockType, _, None) => ()
                    other =>
                      fail(
                        "expected flipped branchy void if after prefix block, got \{@debug.to_string(other)}",
                      )
                  }
                }
                other =>
                  fail(
                    "expected branchy local-set-call parent wrapper to be unwrapped, got \{@debug.to_string(other)}",
                  )
              }
            }
            other =>
              fail(
                "expected outer block for branchy local-set-call prefix test, got \{@debug.to_string(other)}",
              )
          }
      }
    other =>
      fail(
        "expected four defined functions for branchy local-set-call prefix test, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum raw-cleans empty-block call-prefix wrappers before void ifs" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "side" (func $side (param i32 i32 i32)))
      #|  (import "m" "wrap" (func $wrap (param i32) (result i32)))
      #|  (import "m" "pred" (func $pred (param i32) (result i32)))
      #|  (import "m" "release" (func $release (param i32)))
      #|  (memory 1)
      #|  (func (param i32) (local i32 i32 i32)
      #|    (block $outer
      #|      (block
      #|        (block
      #|          (block
      #|            (block)
      #|            (call $side
      #|              (i32.const 0)
      #|              (i32.const 0)
      #|              (i32.sub
      #|                (call $wrap
      #|                  (local.tee 1
      #|                    (i32.load (local.get 0))
      #|                  )
      #|                )
      #|                (i32.const 1)
      #|              )
      #|            )
      #|            (if
      #|              (i32.eq
      #|                (call $pred
      #|                  (local.tee 2
      #|                    (call $wrap
      #|                      (i32.load (local.get 1))
      #|                    )
      #|                  )
      #|                )
      #|                (i32.const 1)
      #|              )
      #|              (then
      #|                (call $release (local.get 2))
      #|              )
      #|              (else
      #|                (local.set 3 (i32.load (local.get 2)))
      #|                (br $outer)
      #|              )
      #|            )
      #|          )
      #|        )
      #|      )
      #|    )
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected empty-block call-prefix vacuum success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected empty-block call-prefix vacuum output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      match instrs[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) =>
          match outer_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) => {
              let cleaned_body = match prefix_body[0] {
                @lib.Block(@lib.VoidBlockType, @lib.Expr(child_body)) =>
                  child_body
                _ => prefix_body
              }
              match cleaned_body[0] {
                @lib.Block(@lib.VoidBlockType, @lib.Expr([])) =>
                  fail(
                    "expected leading empty child block to be removed from call-prefix wrapper",
                  )
                @lib.I32Const(@lib.I32(value)) => @debug.assert_eq(value, 0)
                other =>
                  fail(
                    "expected call-prefix wrapper to start with lowered call argument after empty block cleanup, got \{@debug.to_string(other)}",
                  )
              }
              match cleaned_body[cleaned_body.length() - 1] {
                @lib.If(@lib.VoidBlockType, _, Some(_)) => ()
                other =>
                  fail(
                    "expected cleaned call-prefix wrapper to end with the trailing void if, got \{@debug.to_string(other)}",
                  )
              }
            }
            other =>
              fail(
                "expected call-prefix wrapper to remain while leading empty child is cleaned, got \{@debug.to_string(other)}",
              )
          }
        other =>
          fail(
            "expected outer block for empty-block call-prefix test, got \{@debug.to_string(other)}",
          )
      }
    other =>
      fail(
        "expected one defined function for empty-block call-prefix test, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum raw-unwraps nested empty-block call-prefix parent wrappers" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "side" (func $side (param i32 i32 i32)))
      #|  (import "m" "wrap" (func $wrap (param i32) (result i32)))
      #|  (import "m" "pred" (func $pred (param i32) (result i32)))
      #|  (import "m" "release" (func $release (param i32)))
      #|  (memory 1)
      #|  (func (param i32) (local i32 i32 i32)
      #|    (block $outer
      #|      (block
      #|        (block
      #|          (block
      #|            (block
      #|              (block)
      #|              (call $side
      #|                (i32.const 0)
      #|                (i32.const 0)
      #|                (i32.sub
      #|                  (call $wrap
      #|                    (local.tee 1
      #|                      (i32.load (local.get 0))
      #|                    )
      #|                  )
      #|                  (i32.const 1)
      #|                )
      #|              )
      #|              (if
      #|                (i32.eq
      #|                  (call $pred
      #|                    (local.tee 2
      #|                      (call $wrap
      #|                        (i32.load (local.get 1))
      #|                      )
      #|                    )
      #|                  )
      #|                  (i32.const 1)
      #|                )
      #|                (then
      #|                  (call $release (local.get 2))
      #|                )
      #|                (else
      #|                  (local.set 3 (i32.load (local.get 2)))
      #|                  (br $outer)
      #|                )
      #|              )
      #|            )
      #|          )
      #|        )
      #|      )
      #|    )
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected nested empty-block call-prefix vacuum success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected nested empty-block call-prefix vacuum output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      match instrs[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) =>
          match outer_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) => {
              match prefix_body[0] {
                @lib.Block(_, _) =>
                  fail(
                    "expected nested parent wrapper to be removed after empty-block call-prefix cleanup",
                  )
                @lib.I32Const(@lib.I32(value)) => @debug.assert_eq(value, 0)
                other =>
                  fail(
                    "expected nested call-prefix wrapper to start with lowered call argument, got \{@debug.to_string(other)}",
                  )
              }
              match prefix_body[prefix_body.length() - 1] {
                @lib.If(@lib.VoidBlockType, _, Some(_)) => ()
                other =>
                  fail(
                    "expected nested call-prefix wrapper to end with trailing void if, got \{@debug.to_string(other)}",
                  )
              }
            }
            other =>
              fail(
                "expected one Binaryen-shaped call-prefix wrapper after nested cleanup, got \{@debug.to_string(other)}",
              )
          }
        other =>
          fail(
            "expected outer block for nested empty-block call-prefix test, got \{@debug.to_string(other)}",
          )
      }
    other =>
      fail(
        "expected one defined function for nested empty-block call-prefix test, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum raw-unwraps artifact continuation call-prefix parent wrappers" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "tag" (func $tag (param i32 i32)))
      #|  (import "m" "alloc" (func $alloc (param i32) (result i32)))
      #|  (import "m" "side" (func $side (param i32 i32 i32)))
      #|  (import "m" "wrap" (func $wrap (param i32) (result i32)))
      #|  (import "m" "pred" (func $pred (param i32) (result i32)))
      #|  (import "m" "release" (func $release (param i32)))
      #|  (memory 1)
      #|  (func (param i32) (result i32)
      #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
      #|    (block $block257
      #|      (block $block256
      #|        (block
      #|          (block
      #|            (call $side
      #|              (i32.const 0)
      #|              (i32.const 0)
      #|              (i32.sub
      #|                (call $wrap
      #|                  (local.tee 1
      #|                    (i32.load (local.get 0))
      #|                  )
      #|                )
      #|                (i32.const 1)
      #|              )
      #|            )
      #|            (if
      #|              (i32.eq
      #|                (call $pred
      #|                  (local.tee 2
      #|                    (call $wrap
      #|                      (i32.load
      #|                        (i32.add (i32.const 0) (local.get 1))
      #|                      )
      #|                    )
      #|                  )
      #|                )
      #|                (i32.const 1)
      #|              )
      #|              (then
      #|                (local.set 3 (i32.load8_u (local.get 2)))
      #|                (call $release (local.get 2))
      #|                (local.set 4 (local.get 3))
      #|              )
      #|              (else
      #|                (call $release (local.get 0))
      #|                (local.set 5 (local.get 2))
      #|                (local.set 6 (i32.load (local.get 2)))
      #|                (if
      #|                  (i32.gt_s
      #|                    (local.tee 7 (call $pred (local.get 2)))
      #|                    (i32.const 1)
      #|                  )
      #|                  (then
      #|                    (call $release (local.get 6))
      #|                  )
      #|                  (else
      #|                    (if
      #|                      (i32.eq (local.get 7) (i32.const 1))
      #|                      (then
      #|                        (call $release (local.get 5))
      #|                      )
      #|                    )
      #|                  )
      #|                )
      #|                (local.set 8 (local.get 6))
      #|                (br $block256)
      #|              )
      #|            )
      #|          )
      #|        )
      #|        (local.set 9 (local.get 4))
      #|        (br $block257)
      #|      )
      #|      (call $tag
      #|        (local.tee 10 (call $alloc (i32.const 4)))
      #|        (i32.const 256)
      #|      )
      #|      (i32.store (local.get 10) (local.get 8))
      #|      (return (local.get 10))
      #|    )
      #|    (local.set 11 (local.get 9))
      #|    (local.get 11)
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail(
        "expected artifact continuation call-prefix vacuum success, got \{err}",
      )
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected artifact continuation call-prefix vacuum output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      match instrs[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(block257_body)) =>
          match block257_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(block256_body)) => {
              match block256_body[0] {
                @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) => {
                  match prefix_body[0] {
                    @lib.Block(_, _) =>
                      fail(
                        "expected artifact-shaped call-prefix parent wrapper to be removed before the block256 continuation",
                      )
                    @lib.I32Const(@lib.I32(value)) => @debug.assert_eq(value, 0)
                    other =>
                      fail(
                        "expected flattened artifact call-prefix to start with lowered side-call argument, got \{@debug.to_string(other)}",
                      )
                  }
                  match prefix_body[prefix_body.length() - 1] {
                    @lib.If(@lib.VoidBlockType, _, Some(_)) => ()
                    other =>
                      fail(
                        "expected flattened artifact call-prefix to end with trailing void if, got \{@debug.to_string(other)}",
                      )
                  }
                }
                other =>
                  fail(
                    "expected artifact prefix block before block256 continuation, got \{@debug.to_string(other)}",
                  )
              }
              match block256_body[block256_body.length() - 1] {
                @lib.Br(_) => ()
                other =>
                  fail(
                    "expected block256 continuation to branch to block257 after local-set lowering, got \{@debug.to_string(other)}",
                  )
              }
            }
            other =>
              fail(
                "expected block256 wrapper inside artifact fixture, got \{@debug.to_string(other)}",
              )
          }
        other =>
          fail(
            "expected block257 wrapper for artifact fixture, got \{@debug.to_string(other)}",
          )
      }
    other =>
      fail(
        "expected one defined function for artifact continuation call-prefix test, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum raw-unwraps leading-empty call-prefix continuation wrappers" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "leaf" (func $leaf (param i32)))
      #|  (import "m" "tag" (func $tag (param i32 i32)))
      #|  (import "m" "side" (func $side (param i32 i32)))
      #|  (import "m" "tri" (func $tri (param i32 i32 i32)))
      #|  (import "m" "release" (func $release (param i32)))
      #|  (memory 1)
      #|  (func (result i32)
      #|    (local i32 i32 i32 i32 i32 i32 i32)
      #|    (block $outer
      #|      (block $middle
      #|        (block
      #|          (block
      #|            (block)
      #|            (call $tri
      #|              (i32.const 1)
      #|              (i32.const 0)
      #|              (i32.sub (i32.const 0) (i32.const 1))
      #|            )
      #|            nop nop nop
      #|            (if
      #|              (i32.eq (i32.const 0) (i32.const 1))
      #|              (then
      #|                (local.set 0 (i32.const 0))
      #|                (call $release (i32.const 1))
      #|                (local.set 1 (i32.const 1))
      #|              )
      #|              (else
      #|                (call $release (i32.const 0))
      #|                (local.set 2 (i32.const 0))
      #|                nop
      #|                (local.set 3 (i32.const 0))
      #|                (if (i32.const 1)
      #|                  (then
      #|                    (call $side (i32.const 1) (i32.const 0))
      #|                    (call $leaf (i32.const 0))
      #|                  )
      #|                  (else
      #|                    (if (i32.const 1)
      #|                      (then (call $leaf (i32.const 0)))
      #|                    )
      #|                  )
      #|                )
      #|                (local.set 4 (i32.const 0))
      #|                (br $middle)
      #|              )
      #|            )
      #|          )
      #|          nop
      #|        )
      #|        (local.set 5 (i32.const 1))
      #|        (br $outer)
      #|      )
      #|      (call $tag (i32.const 0) (i32.const 0))
      #|      (i32.store align=1 (i32.const 0) (i32.const 0))
      #|      (return (i32.const 0))
      #|    )
      #|    (local.set 6 (i32.const 0))
      #|    (i32.const 0)
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail(
        "expected leading-empty call-prefix continuation vacuum success, got \{err}",
      )
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected leading-empty call-prefix continuation output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      match instrs[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) =>
          match outer_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(middle_body)) =>
              match middle_body[0] {
                @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) => {
                  match prefix_body[0] {
                    @lib.Block(_, _) =>
                      fail(
                        "expected trailing-nop parent wrapper to be removed after leading-empty call-prefix cleanup",
                      )
                    @lib.I32Const(@lib.I32(value)) => @debug.assert_eq(value, 1)
                    other =>
                      fail(
                        "expected flattened call-prefix to start with lowered call argument, got \{@debug.to_string(other)}",
                      )
                  }
                  match prefix_body[prefix_body.length() - 1] {
                    @lib.If(@lib.VoidBlockType, _, Some(_)) => ()
                    other =>
                      fail(
                        "expected flattened call-prefix continuation wrapper to end with trailing void if, got \{@debug.to_string(other)}",
                      )
                  }
                }
                other =>
                  fail(
                    "expected call-prefix block before middle continuation, got \{@debug.to_string(other)}",
                  )
              }
            other =>
              fail(
                "expected middle continuation block in leading-empty fixture, got \{@debug.to_string(other)}",
              )
          }
        other =>
          fail(
            "expected outer continuation block in leading-empty fixture, got \{@debug.to_string(other)}",
          )
      }
    other =>
      fail(
        "expected one defined function for leading-empty call-prefix continuation test, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum raw-unwraps binary-lowered line29378 continuation parent wrapper" {
  // Binary-lowered bytes from the reduced slot23 line-29378 first hunk.
  // Text parsing rebuilds this as a higher-level call/if shape, so keep the
  // binary fixture to preserve the extra wrapper that previously survived raw
  // vacuum cleanup.
  let input = match
    @binary.decode_module(
      Bytes::from_array([
        0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x15, 0x04, 0x60, 0x01,
        0x7f, 0x00, 0x60, 0x02, 0x7f, 0x7f, 0x00, 0x60, 0x03, 0x7f, 0x7f, 0x7f, 0x00,
        0x60, 0x01, 0x7f, 0x01, 0x7f, 0x02, 0x37, 0x06, 0x03, 0x65, 0x6e, 0x76, 0x02,
        0x66, 0x30, 0x00, 0x00, 0x03, 0x65, 0x6e, 0x76, 0x02, 0x66, 0x31, 0x00, 0x01,
        0x03, 0x65, 0x6e, 0x76, 0x02, 0x66, 0x32, 0x00, 0x01, 0x03, 0x65, 0x6e, 0x76,
        0x02, 0x66, 0x34, 0x00, 0x02, 0x03, 0x65, 0x6e, 0x76, 0x02, 0x66, 0x35, 0x00,
        0x00, 0x03, 0x65, 0x6e, 0x76, 0x02, 0x66, 0x36, 0x00, 0x00, 0x03, 0x02, 0x01,
        0x03, 0x05, 0x03, 0x01, 0x00, 0x01, 0x07, 0x05, 0x01, 0x01, 0x66, 0x00, 0x06,
        0x0a, 0x7c, 0x01, 0x7a, 0x01, 0x08, 0x7f, 0x02, 0x40, 0x02, 0x40, 0x02, 0x40,
        0x02, 0x40, 0x02, 0x40, 0x01, 0x0b, 0x41, 0x01, 0x41, 0x00, 0x41, 0x01, 0x41,
        0x01, 0x6b, 0x10, 0x03, 0x20, 0x01, 0x04, 0x40, 0x41, 0x00, 0x21, 0x02, 0x41,
        0x01, 0x10, 0x05, 0x41, 0x00, 0x21, 0x03, 0x05, 0x41, 0x01, 0x10, 0x05, 0x41,
        0x00, 0x21, 0x04, 0x41, 0x00, 0x21, 0x05, 0x41, 0x00, 0x04, 0x40, 0x41, 0x01,
        0x41, 0x00, 0x10, 0x02, 0x41, 0x01, 0x10, 0x04, 0x05, 0x41, 0x00, 0x04, 0x40,
        0x41, 0x00, 0x10, 0x00, 0x0b, 0x0b, 0x41, 0x00, 0x21, 0x06, 0x0c, 0x03, 0x0b,
        0x0b, 0x01, 0x0b, 0x41, 0x00, 0x21, 0x07, 0x0c, 0x01, 0x0b, 0x41, 0x01, 0x41,
        0x00, 0x10, 0x01, 0x41, 0x00, 0x41, 0x01, 0x36, 0x00, 0x00, 0x41, 0x00, 0x0f,
        0x0b, 0x41, 0x00, 0x21, 0x08, 0x41, 0x00, 0x0f, 0x0b,
      ]),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected binary-lowered line29378 fixture to decode, got \{err}")
  }
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected binary-lowered line29378 vacuum success, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      match instrs[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) =>
          match outer_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(middle_body)) =>
              match middle_body[0] {
                @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) =>
                  match prefix_body[0] {
                    @lib.Block(_, _) =>
                      fail(
                        "expected binary-lowered line29378 parent wrapper to be removed",
                      )
                    @lib.I32Const(@lib.I32(value)) => @debug.assert_eq(value, 1)
                    other =>
                      fail(
                        "expected lowered call argument, got \{@debug.to_string(other)}",
                      )
                  }
                other =>
                  fail(
                    "expected call-prefix block, got \{@debug.to_string(other)}",
                  )
              }
            other =>
              fail("expected middle block, got \{@debug.to_string(other)}")
          }
        other => fail("expected outer block, got \{@debug.to_string(other)}")
      }
    other =>
      fail("expected one defined function, got \{@debug.to_string(other)}")
  }
}

///|
test "vacuum raw-unwraps no-nop line29378 refcount call-prefix parent wrapper" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "drop_old" (func $drop_old (param i32)))
      #|  (import "m" "pred" (func $pred (param i32) (result i32)))
      #|  (import "m" "dec" (func $dec (param i32 i32)))
      #|  (import "m" "side" (func $side (param i32 i32 i32)))
      #|  (import "m" "wrap" (func $wrap (param i32) (result i32)))
      #|  (import "m" "lookup" (func $lookup (param i32) (result i32)))
      #|  (memory 1)
      #|  (func (param i32) (result i32)
      #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
      #|    (block $outer
      #|      (block $mid
      #|        (block
      #|          (block
      #|            (local.set 1 (i32.load align=1 (local.get 0)))
      #|            (if
      #|              (i32.gt_s
      #|                (local.tee 2 (call $pred (local.get 0)))
      #|                (i32.const 1)
      #|              )
      #|              (then
      #|                (call $dec (local.get 0) (i32.sub (local.get 2) (i32.const 1)))
      #|                (call $drop_old (local.get 1))
      #|              )
      #|              (else
      #|                (if
      #|                  (i32.eq (local.get 2) (i32.const 1))
      #|                  (then (call $drop_old (i32.sub (local.get 0) (i32.const 8))))
      #|                )
      #|              )
      #|            )
      #|            (call $side
      #|              (i32.const 15)
      #|              (i32.const 0)
      #|              (i32.sub (call $wrap (local.get 1)) (i32.const 1))
      #|            )
      #|            (local.set 3 (i32.load align=1 (i32.add (i32.const 60) (local.get 1))))
      #|            (call $drop_old (local.get 1))
      #|            (if
      #|              (i32.eq
      #|                (call $pred (local.tee 4 (call $lookup (local.get 3))))
      #|                (i32.const 1)
      #|              )
      #|              (then
      #|                (local.set 5 (i32.load8_u (local.get 4)))
      #|                (call $drop_old (local.get 4))
      #|                (local.set 6 (local.get 5))
      #|              )
      #|              (else
      #|                (local.set 7 (local.get 4))
      #|                (local.set 8 (i32.load align=1 (local.get 4)))
      #|                (if
      #|                  (i32.gt_s (local.tee 9 (call $pred (local.get 4))) (i32.const 1))
      #|                  (then
      #|                    (call $dec (local.get 4) (i32.sub (local.get 9) (i32.const 1)))
      #|                    (call $drop_old (local.get 8))
      #|                  )
      #|                  (else
      #|                    (if
      #|                      (i32.eq (local.get 9) (i32.const 1))
      #|                      (then (call $drop_old (i32.sub (local.get 7) (i32.const 8))))
      #|                    )
      #|                  )
      #|                )
      #|                (local.set 10 (local.get 8))
      #|                (br $mid)
      #|              )
      #|            )
      #|          )
      #|        )
      #|        (local.set 11 (local.get 6))
      #|        (br $outer)
      #|      )
      #|      (call $side (i32.const 1) (i32.const 0) (i32.const 0))
      #|      (i32.store align=1 (i32.const 0) (local.get 10))
      #|      (return (i32.const 0))
      #|    )
      #|    (local.get 11)
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected no-nop line29378 refcount wrapper vacuum success, got \{err}",
      )
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected no-nop line29378 refcount wrapper output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      match instrs[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) =>
          match outer_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(mid_body)) =>
              match mid_body[0] {
                @lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body)) =>
                  match parent_body[0] {
                    @lib.Block(_, _) =>
                      fail(
                        "expected no-nop line29378 parent wrapper child block to be removed",
                      )
                    @lib.LocalGet(_) | @lib.LocalSet(_) => ()
                    other =>
                      fail(
                        "expected no-nop line29378 body to start with lowered local load/set, got \{@debug.to_string(other)}",
                      )
                  }
                other =>
                  fail(
                    "expected no-nop line29378 parent block, got \{@debug.to_string(other)}",
                  )
              }
            other =>
              fail("expected middle block, got \{@debug.to_string(other)}")
          }
        other => fail("expected outer block, got \{@debug.to_string(other)}")
      }
    other =>
      fail("expected one defined function, got \{@debug.to_string(other)}")
  }
}

///|
test "vacuum flattens single-if wrappers without leading empty prefixes" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "make" (func $make (param i32) (result i32)))
      #|  (import "m" "pred" (func $pred (param i32) (result i32)))
      #|  (import "m" "release" (func $release (param i32)))
      #|  (memory 1)
      #|  (func (param i32) (local i32 i32 i32)
      #|    (block
      #|      (block $mid
      #|        (block
      #|          nop nop nop nop nop nop nop nop
      #|          nop nop nop nop nop nop nop nop
      #|          (if
      #|            (i32.eq
      #|              (local.tee 3
      #|                (call $pred
      #|                  (local.tee 1
      #|                    (i32.load
      #|                      (local.tee 2 (call $make (local.get 0)))
      #|                    )
      #|                  )
      #|                )
      #|              )
      #|              (i32.const 4)
      #|            )
      #|            (then
      #|              (call $release (local.get 1))
      #|              (br $mid)
      #|            )
      #|            (else
      #|              (call $release (local.get 2))
      #|            )
      #|          )
      #|        )
      #|      )
      #|    )
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) => fail("expected single-if wrapper vacuum success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected single-if wrapper vacuum output to validate, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      match instrs[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(body)) => {
          // Binaryen direct `--vacuum` removes both the anonymous outer wrapper
          // and the inner single-if wrapper, leaving only the branch-target
          // block. The lowered Starshine AST keeps condition operands as
          // siblings before the final `if`, so assert the remaining structural
          // guard instead of expecting a now-stale middle block.
          match body[0] {
            @lib.Block(_, _) =>
              fail(
                "expected single-if wrapper without leading empty prefix to be flattened, got extra block",
              )
            _ => ()
          }
          match body[body.length() - 1] {
            @lib.If(@lib.VoidBlockType, _, Some(_)) => ()
            other =>
              fail(
                "expected flattened single-if wrapper to end with if, got \{@debug.to_string(other)}",
              )
          }
        }
        other =>
          fail(
            "expected remaining branch-target block for single-if wrapper fixture, got \{@debug.to_string(other)}",
          )
      }
    other =>
      fail(
        "expected one defined function for single-if wrapper fixture, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum preserves binary-lowered defined5022 five-arg prefix child block" {
  // Binary-lowered bytes from the reduced slot23 defined=5022 residual.
  // Text parsing rebuilds the surrounding control enough that a WAT fixture does
  // not reproduce the parity gap; keep this binary seed until the exact
  // lower-level shape has a smaller source-backed construction.
  let input = match
    @binary.decode_module(
      Bytes::from_array([
        0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x1e, 0x05, 0x60, 0x01,
        0x7f, 0x00, 0x60, 0x01, 0x7f, 0x01, 0x7f, 0x60, 0x02, 0x7f, 0x7f, 0x00, 0x60,
        0x02, 0x7f, 0x7f, 0x01, 0x7f, 0x60, 0x05, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x01,
        0x7f, 0x02, 0xa3, 0x01, 0x0a, 0x03, 0x65, 0x6e, 0x76, 0x09, 0x66, 0x69, 0x6d,
        0x70, 0x6f, 0x72, 0x74, 0x24, 0x30, 0x00, 0x00, 0x03, 0x65, 0x6e, 0x76, 0x09,
        0x66, 0x69, 0x6d, 0x70, 0x6f, 0x72, 0x74, 0x24, 0x31, 0x00, 0x01, 0x03, 0x65,
        0x6e, 0x76, 0x09, 0x66, 0x69, 0x6d, 0x70, 0x6f, 0x72, 0x74, 0x24, 0x32, 0x00,
        0x02, 0x03, 0x65, 0x6e, 0x76, 0x09, 0x66, 0x69, 0x6d, 0x70, 0x6f, 0x72, 0x74,
        0x24, 0x33, 0x00, 0x01, 0x03, 0x65, 0x6e, 0x76, 0x09, 0x66, 0x69, 0x6d, 0x70,
        0x6f, 0x72, 0x74, 0x24, 0x34, 0x00, 0x02, 0x03, 0x65, 0x6e, 0x76, 0x09, 0x66,
        0x69, 0x6d, 0x70, 0x6f, 0x72, 0x74, 0x24, 0x35, 0x00, 0x01, 0x03, 0x65, 0x6e,
        0x76, 0x09, 0x66, 0x69, 0x6d, 0x70, 0x6f, 0x72, 0x74, 0x24, 0x36, 0x00, 0x00,
        0x03, 0x65, 0x6e, 0x76, 0x09, 0x66, 0x69, 0x6d, 0x70, 0x6f, 0x72, 0x74, 0x24,
        0x37, 0x00, 0x00, 0x03, 0x65, 0x6e, 0x76, 0x0a, 0x66, 0x69, 0x6d, 0x70, 0x6f,
        0x72, 0x74, 0x24, 0x31, 0x30, 0x00, 0x04, 0x03, 0x65, 0x6e, 0x76, 0x0a, 0x66,
        0x69, 0x6d, 0x70, 0x6f, 0x72, 0x74, 0x24, 0x31, 0x31, 0x00, 0x03, 0x03, 0x02,
        0x01, 0x03, 0x05, 0x03, 0x01, 0x00, 0x04, 0x0c, 0x02, 0xa9, 0x04, 0x0a, 0x7b,
        0x01, 0x79, 0x01, 0xb5, 0x4b, 0x7f, 0x02, 0x40, 0x02, 0x40, 0x02, 0x40, 0x02,
        0x40, 0x41, 0x00, 0x20, 0x7e, 0x20, 0x7f, 0x20, 0x7d, 0x20, 0x80, 0x01, 0x10,
        0x08, 0x21, 0xe4, 0x0a, 0x20, 0x7f, 0x10, 0x07, 0x20, 0x7d, 0x10, 0x07, 0x01,
        0x20, 0x80, 0x01, 0x10, 0x07, 0x0b, 0x41, 0x00, 0x10, 0x05, 0x04, 0x40, 0x01,
        0x01, 0x41, 0x00, 0x10, 0x03, 0x22, 0xfb, 0x07, 0x41, 0x01, 0x4a, 0x04, 0x40,
        0x01, 0x05, 0x41, 0x00, 0x41, 0x00, 0x6b, 0x10, 0x00, 0x0b, 0x01, 0x01, 0x01,
        0x01, 0x05, 0x41, 0x00, 0x28, 0x00, 0x00, 0x21, 0xec, 0x07, 0x01, 0x01, 0x01,
        0x01, 0x01, 0x01, 0x01, 0x0c, 0x03, 0x0b, 0x0b, 0x0b, 0x41, 0x00, 0x21, 0xe5,
        0x0a, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x0b, 0x01,
        0x01, 0x01, 0x01, 0x01, 0x00, 0x0b, 0x0b, 0xcf, 0x15, 0xa9, 0x04, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
      ]),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected binary-lowered defined5022 fixture to decode, got \{err}")
  }
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected binary-lowered defined5022 vacuum success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected binary-lowered defined5022 vacuum output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      match instrs[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) =>
          match outer_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body)) =>
              match parent_body[0] {
                @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) =>
                  match prefix_body[0] {
                    @lib.I32Const(_) | @lib.LocalGet(_) => ()
                    other =>
                      fail(
                        "expected preserved defined5022 prefix block to start with the five-arg allocator local.set prefix, got \{@debug.to_string(other)}",
                      )
                  }
                other =>
                  fail(
                    "expected Binaryen-preserved defined5022 child prefix block before branchy refcount if, got \{@debug.to_string(other)}",
                  )
              }
            other =>
              fail(
                "expected defined5022 parent block, got \{@debug.to_string(other)}",
              )
          }
        other =>
          fail(
            "expected defined5022 outer block, got \{@debug.to_string(other)}",
          )
      }
    other =>
      fail(
        "expected one defined function for defined5022 binary fixture, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum preserves full-context first-hunk five-arg prefix parent wrapper" {
  // Binary-lowered 425-byte repro from `.tmp/vacuum-probes/fullcontext-firsthunk-manual.wasm`.
  // The source WAT parses through wasm-tools into the shape that native compare
  // keeps red, while Starshine's in-repo WAT path rebuilds enough structure to
  // miss the parent/label-depth-sensitive wrapper. Keep the binary fixture as
  // red-first coverage for the open slot23 `defined=5022 abs=5049` residual.
  let input = match
    @binary.decode_module(
      Bytes::from_array([
        0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x1f, 0x05, 0x60, 0x01,
        0x7f, 0x00, 0x60, 0x01, 0x7f, 0x01, 0x7f, 0x60, 0x02, 0x7f, 0x7f, 0x00, 0x60,
        0x05, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x01, 0x7f, 0x60, 0x03, 0x7f, 0x7f, 0x7f,
        0x01, 0x7f, 0x03, 0x0c, 0x0b, 0x00, 0x01, 0x02, 0x01, 0x02, 0x01, 0x00, 0x00,
        0x03, 0x04, 0x01, 0x05, 0x03, 0x01, 0x00, 0x01, 0x07, 0x08, 0x01, 0x04, 0x74,
        0x65, 0x73, 0x74, 0x00, 0x0a, 0x0a, 0x86, 0x02, 0x0b, 0x02, 0x00, 0x0b, 0x04,
        0x00, 0x20, 0x00, 0x0b, 0x02, 0x00, 0x0b, 0x04, 0x00, 0x20, 0x00, 0x0b, 0x02,
        0x00, 0x0b, 0x04, 0x00, 0x20, 0x00, 0x0b, 0x02, 0x00, 0x0b, 0x02, 0x00, 0x0b,
        0x04, 0x00, 0x20, 0x00, 0x0b, 0x04, 0x00, 0x20, 0x00, 0x0b, 0xdb, 0x01, 0x01,
        0x19, 0x7f, 0x20, 0x00, 0x28, 0x00, 0x00, 0x21, 0x01, 0x02, 0x40, 0x02, 0x40,
        0x02, 0x40, 0x02, 0x40, 0x01, 0x01, 0x01, 0x20, 0x00, 0x20, 0x02, 0x20, 0x03,
        0x20, 0x04, 0x20, 0x05, 0x10, 0x08, 0x21, 0x14, 0x01, 0x20, 0x03, 0x10, 0x07,
        0x01, 0x20, 0x04, 0x10, 0x07, 0x01, 0x20, 0x05, 0x10, 0x07, 0x0b, 0x01, 0x01,
        0x20, 0x14, 0x22, 0x06, 0x10, 0x05, 0x41, 0x01, 0x46, 0x04, 0x40, 0x01, 0x20,
        0x06, 0x22, 0x07, 0x28, 0x00, 0x00, 0x21, 0x08, 0x20, 0x07, 0x10, 0x03, 0x22,
        0x09, 0x41, 0x01, 0x4a, 0x04, 0x40, 0x20, 0x07, 0x20, 0x09, 0x41, 0x01, 0x6b,
        0x10, 0x04, 0x20, 0x08, 0x10, 0x06, 0x05, 0x20, 0x09, 0x41, 0x01, 0x46, 0x04,
        0x40, 0x20, 0x07, 0x41, 0x08, 0x6b, 0x10, 0x00, 0x0b, 0x0b, 0x20, 0x08, 0x21,
        0x0a, 0x05, 0x01, 0x20, 0x06, 0x22, 0x0b, 0x28, 0x00, 0x00, 0x21, 0x0c, 0x20,
        0x0b, 0x10, 0x03, 0x22, 0x0d, 0x41, 0x01, 0x4a, 0x04, 0x40, 0x20, 0x0b, 0x20,
        0x0d, 0x41, 0x01, 0x6b, 0x10, 0x04, 0x20, 0x0c, 0x10, 0x06, 0x05, 0x20, 0x0d,
        0x41, 0x01, 0x46, 0x04, 0x40, 0x20, 0x0b, 0x41, 0x08, 0x6b, 0x10, 0x00, 0x0b,
        0x0b, 0x20, 0x0c, 0x21, 0x0e, 0x0c, 0x03, 0x0b, 0x0b, 0x0b, 0x20, 0x0a, 0x20,
        0x01, 0x20, 0x02, 0x10, 0x09, 0x21, 0x15, 0x20, 0x0a, 0x10, 0x07, 0x41, 0x04,
        0x10, 0x01, 0x22, 0x16, 0x41, 0x81, 0x02, 0x10, 0x02, 0x20, 0x16, 0x20, 0x15,
        0x36, 0x00, 0x00, 0x20, 0x16, 0x0f, 0x0b, 0x41, 0x00, 0x0b, 0x00, 0x58, 0x04,
        0x6e, 0x61, 0x6d, 0x65, 0x01, 0x51, 0x0a, 0x00, 0x05, 0x64, 0x72, 0x6f, 0x70,
        0x31, 0x01, 0x06, 0x61, 0x6c, 0x6c, 0x6f, 0x63, 0x31, 0x02, 0x06, 0x73, 0x74,
        0x6f, 0x72, 0x65, 0x32, 0x03, 0x06, 0x72, 0x65, 0x66, 0x63, 0x6e, 0x74, 0x04,
        0x06, 0x73, 0x65, 0x74, 0x72, 0x65, 0x66, 0x05, 0x05, 0x69, 0x73, 0x6f, 0x6e,
        0x65, 0x06, 0x05, 0x76, 0x69, 0x73, 0x69, 0x74, 0x07, 0x07, 0x72, 0x65, 0x6c,
        0x65, 0x61, 0x73, 0x65, 0x08, 0x06, 0x61, 0x6c, 0x6c, 0x6f, 0x63, 0x35, 0x09,
        0x08, 0x63, 0x6f, 0x6d, 0x62, 0x69, 0x6e, 0x65, 0x33,
      ]),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected full-context first-hunk fixture to decode, got \{err}")
  }
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected full-context first-hunk vacuum success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected full-context first-hunk vacuum output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(instrs)) = funcs[funcs.length() - 1]
      let mut block_idx = -1
      let mut search_idx = 0
      while block_idx < 0 && search_idx < instrs.length() {
        match instrs[search_idx] {
          @lib.Block(@lib.VoidBlockType, _) => block_idx = search_idx
          _ => ()
        }
        search_idx = search_idx + 1
      }
      if block_idx < 0 {
        fail(
          "expected full-context first-hunk fixture to contain an outer continuation block",
        )
      }
      match instrs[block_idx] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) =>
          match outer_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body)) => {
              match parent_body[0] {
                @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) =>
                  match prefix_body[0] {
                    @lib.I32Const(_) | @lib.LocalGet(_) => ()
                    other =>
                      fail(
                        "expected full-context first-hunk five-arg prefix child block to start with five-arg allocator operands, got \{@debug.to_string(other)}",
                      )
                  }
                other =>
                  fail(
                    "expected Binaryen-preserved full-context first-hunk child prefix block before branchy refcount if, got \{@debug.to_string(other)}",
                  )
              }
              let mut saw_following_if = false
              for idx = 1; idx < parent_body.length(); idx = idx + 1 {
                match parent_body[idx] {
                  @lib.If(@lib.VoidBlockType, _, Some(_)) =>
                    saw_following_if = true
                  _ => ()
                }
              }
              if !saw_following_if {
                fail(
                  "expected Binaryen-preserved full-context first-hunk parent body to keep following void if",
                )
              }
            }
            other =>
              fail(
                "expected full-context first-hunk parent block, got \{@debug.to_string(other)}",
              )
          }
        other =>
          fail(
            "expected full-context first-hunk outer continuation block, got \{@debug.to_string(other)}",
          )
      }
    }
    None => fail("expected code section for full-context first-hunk fixture")
  }
}

///|
test "vacuum preserves nop-separated full-context five-arg prefix parent wrapper" {
  // Variant of `.tmp/vacuum-probes/fullcontext-firsthunk-manual.wasm` with raw
  // `nop` roots between the parent wrapper and the following allocation/use
  // continuation. Binaryen keeps the parent wrapper after cleaning the nops;
  // Starshine must not treat the nop-separated continuation as a generic
  // wrapper-flattening opportunity.
  let input = match
    @binary.decode_module(
      Bytes::from_array([
        0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x1f, 0x05, 0x60, 0x01,
        0x7f, 0x00, 0x60, 0x01, 0x7f, 0x01, 0x7f, 0x60, 0x02, 0x7f, 0x7f, 0x00, 0x60,
        0x05, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x01, 0x7f, 0x60, 0x03, 0x7f, 0x7f, 0x7f,
        0x01, 0x7f, 0x03, 0x0c, 0x0b, 0x00, 0x01, 0x02, 0x01, 0x02, 0x01, 0x00, 0x00,
        0x03, 0x04, 0x01, 0x05, 0x03, 0x01, 0x00, 0x01, 0x07, 0x08, 0x01, 0x04, 0x74,
        0x65, 0x73, 0x74, 0x00, 0x0a, 0x0a, 0x89, 0x02, 0x0b, 0x02, 0x00, 0x0b, 0x04,
        0x00, 0x20, 0x00, 0x0b, 0x02, 0x00, 0x0b, 0x04, 0x00, 0x20, 0x00, 0x0b, 0x02,
        0x00, 0x0b, 0x04, 0x00, 0x20, 0x00, 0x0b, 0x02, 0x00, 0x0b, 0x02, 0x00, 0x0b,
        0x04, 0x00, 0x20, 0x00, 0x0b, 0x04, 0x00, 0x20, 0x00, 0x0b, 0xde, 0x01, 0x01,
        0x19, 0x7f, 0x20, 0x00, 0x28, 0x00, 0x00, 0x21, 0x01, 0x02, 0x40, 0x02, 0x40,
        0x02, 0x40, 0x02, 0x40, 0x01, 0x01, 0x01, 0x20, 0x00, 0x20, 0x02, 0x20, 0x03,
        0x20, 0x04, 0x20, 0x05, 0x10, 0x08, 0x21, 0x14, 0x01, 0x20, 0x03, 0x10, 0x07,
        0x01, 0x20, 0x04, 0x10, 0x07, 0x01, 0x20, 0x05, 0x10, 0x07, 0x0b, 0x01, 0x01,
        0x20, 0x14, 0x22, 0x06, 0x10, 0x05, 0x41, 0x01, 0x46, 0x04, 0x40, 0x01, 0x20,
        0x06, 0x22, 0x07, 0x28, 0x00, 0x00, 0x21, 0x08, 0x20, 0x07, 0x10, 0x03, 0x22,
        0x09, 0x41, 0x01, 0x4a, 0x04, 0x40, 0x20, 0x07, 0x20, 0x09, 0x41, 0x01, 0x6b,
        0x10, 0x04, 0x20, 0x08, 0x10, 0x06, 0x05, 0x20, 0x09, 0x41, 0x01, 0x46, 0x04,
        0x40, 0x20, 0x07, 0x41, 0x08, 0x6b, 0x10, 0x00, 0x0b, 0x0b, 0x20, 0x08, 0x21,
        0x0a, 0x05, 0x01, 0x20, 0x06, 0x22, 0x0b, 0x28, 0x00, 0x00, 0x21, 0x0c, 0x20,
        0x0b, 0x10, 0x03, 0x22, 0x0d, 0x41, 0x01, 0x4a, 0x04, 0x40, 0x20, 0x0b, 0x20,
        0x0d, 0x41, 0x01, 0x6b, 0x10, 0x04, 0x20, 0x0c, 0x10, 0x06, 0x05, 0x20, 0x0d,
        0x41, 0x01, 0x46, 0x04, 0x40, 0x20, 0x0b, 0x41, 0x08, 0x6b, 0x10, 0x00, 0x0b,
        0x0b, 0x20, 0x0c, 0x21, 0x0e, 0x0c, 0x03, 0x0b, 0x0b, 0x0b, 0x01, 0x01, 0x01,
        0x20, 0x0a, 0x20, 0x01, 0x20, 0x02, 0x10, 0x09, 0x21, 0x15, 0x20, 0x0a, 0x10,
        0x07, 0x41, 0x04, 0x10, 0x01, 0x22, 0x16, 0x41, 0x81, 0x02, 0x10, 0x02, 0x20,
        0x16, 0x20, 0x15, 0x36, 0x00, 0x00, 0x20, 0x16, 0x0f, 0x0b, 0x41, 0x00, 0x0b,
        0x00, 0x58, 0x04, 0x6e, 0x61, 0x6d, 0x65, 0x01, 0x51, 0x0a, 0x00, 0x05, 0x64,
        0x72, 0x6f, 0x70, 0x31, 0x01, 0x06, 0x61, 0x6c, 0x6c, 0x6f, 0x63, 0x31, 0x02,
        0x06, 0x73, 0x74, 0x6f, 0x72, 0x65, 0x32, 0x03, 0x06, 0x72, 0x65, 0x66, 0x63,
        0x6e, 0x74, 0x04, 0x06, 0x73, 0x65, 0x74, 0x72, 0x65, 0x66, 0x05, 0x05, 0x69,
        0x73, 0x6f, 0x6e, 0x65, 0x06, 0x05, 0x76, 0x69, 0x73, 0x69, 0x74, 0x07, 0x07,
        0x72, 0x65, 0x6c, 0x65, 0x61, 0x73, 0x65, 0x08, 0x06, 0x61, 0x6c, 0x6c, 0x6f,
        0x63, 0x35, 0x09, 0x08, 0x63, 0x6f, 0x6d, 0x62, 0x69, 0x6e, 0x65, 0x33,
      ]),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nop-separated full-context first-hunk fixture to decode, got \{err}",
      )
  }
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nop-separated full-context first-hunk vacuum success, got \{err}",
      )
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected nop-separated full-context first-hunk vacuum output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(instrs)) = funcs[funcs.length() - 1]
      let mut block_idx = -1
      let mut search_idx = 0
      while block_idx < 0 && search_idx < instrs.length() {
        match instrs[search_idx] {
          @lib.Block(@lib.VoidBlockType, _) => block_idx = search_idx
          _ => ()
        }
        search_idx = search_idx + 1
      }
      if block_idx < 0 {
        fail(
          "expected nop-separated full-context first-hunk fixture to contain an outer continuation block",
        )
      }
      match instrs[block_idx] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) =>
          match outer_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body)) => {
              match parent_body[0] {
                @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) =>
                  match prefix_body[0] {
                    @lib.I32Const(_) | @lib.LocalGet(_) => ()
                    other =>
                      fail(
                        "expected nop-separated full-context five-arg prefix child block to start with five-arg allocator operands, got \{@debug.to_string(other)}",
                      )
                  }
                other =>
                  fail(
                    "expected Binaryen-preserved nop-separated full-context child prefix block before branchy refcount if, got \{@debug.to_string(other)}",
                  )
              }
              let mut saw_following_if = false
              for idx = 1; idx < parent_body.length(); idx = idx + 1 {
                match parent_body[idx] {
                  @lib.If(@lib.VoidBlockType, _, Some(_)) =>
                    saw_following_if = true
                  _ => ()
                }
              }
              if !saw_following_if {
                fail(
                  "expected Binaryen-preserved nop-separated full-context parent body to keep following void if",
                )
              }
            }
            other =>
              fail(
                "expected nop-separated full-context first-hunk parent block, got \{@debug.to_string(other)}",
              )
          }
        other =>
          fail(
            "expected nop-separated full-context first-hunk outer continuation block, got \{@debug.to_string(other)}",
          )
      }
    }
    None =>
      fail(
        "expected code section for nop-separated full-context first-hunk fixture",
      )
  }
}

///|
test "vacuum preserves release-update void if arm drops" {
  // Slot23 `defined=1259 abs=1286` follows f1224: Binaryen keeps the
  // release/update arms as a void `if` with per-arm dropped result calls when
  // each arm first loads/stores a local and releases the shared object.
  // Starshine's dropped-result-if packing remains valid for pure emit arms,
  // but this loop-local update shape must stay Binaryen-shaped.
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "release" (func $release (param i32)))
      #|  (import "m" "emit" (func $emit (param i32 i32 i32) (result i32)))
      #|  (memory 1)
      #|  (func (export "test") (param i32 i32 i32 i32) (result i32)
      #|    (local i32 i32)
      #|    (if (local.get 0)
      #|      (then
      #|        (local.set 4 (i32.load offset=4 align=1 (local.get 1)))
      #|        (call $release (local.get 1))
      #|        (drop (call $emit (local.get 2) (local.get 4) (i32.const 1))))
      #|      (else
      #|        (local.set 5 (i32.load offset=4 align=1 (local.get 1)))
      #|        (call $release (local.get 1))
      #|        (drop (call $emit (local.get 2) (local.get 5) (i32.const 0)))))
      #|    (local.get 3))
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) => fail("expected f1259 vacuum success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected f1259 output to validate, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) => {
      let mut saw_void_if_with_arm_drops = false
      for idx = 0; idx < instrs.length(); idx = idx + 1 {
        match instrs[idx] {
          @lib.If(@lib.ValTypeBlockType(vt), _, Some(_)) if vt ==
            @lib.ValType::i32() &&
            idx + 1 < instrs.length() &&
            instrs[idx + 1] is @lib.Drop =>
            fail(
              "expected f1259 release/update arms to stay void, got result-if packing",
            )
          @lib.If(@lib.VoidBlockType, then_body, Some(else_body)) =>
            if then_body.any(fn(instr) { instr is @lib.Drop }) &&
              else_body.any(fn(instr) { instr is @lib.Drop }) {
              saw_void_if_with_arm_drops = true
            }
          _ => ()
        }
      }
      assert_true(saw_void_if_with_arm_drops, msg=@debug.to_string(instrs))
    }
    other =>
      fail(
        "expected one defined function for f1259 fixture, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum packs dropped result-if call arms after nop cleanup" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "emit" (func $emit (param i32 i32) (result i32)))
      #|  (func (export "test") (param i32 i32 i32) (result i32)
      #|    (local i32)
      #|    (local.set 3 (i32.le_s (local.get 1) (i32.const 255)))
      #|    (if (local.get 3)
      #|      (then
      #|        nop nop
      #|        (drop
      #|          (call $emit
      #|            (local.get 0)
      #|            (i32.and (local.get 1) (i32.const 255)))))
      #|      (else
      #|        nop nop
      #|        (drop
      #|          (call $emit
      #|            (local.get 0)
      #|            (i32.const 63)))))
      #|    (local.get 1))
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) => fail("expected dropped result-if vacuum success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected dropped result-if output to validate, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) => {
      let mut saw_result_if = false
      let mut saw_drop_after_result_if = false
      for idx = 0; idx < instrs.length(); idx = idx + 1 {
        match instrs[idx] {
          @lib.If(@lib.ValTypeBlockType(vt), _, Some(_)) if vt ==
            @lib.ValType::i32() => {
            saw_result_if = true
            if idx + 1 < instrs.length() && instrs[idx + 1] is @lib.Drop {
              saw_drop_after_result_if = true
            }
          }
          @lib.If(@lib.VoidBlockType, then_body, Some(else_body)) =>
            if then_body.any(fn(instr) { instr is @lib.Drop }) ||
              else_body.any(fn(instr) { instr is @lib.Drop }) {
              fail(
                "expected Binaryen-style dropped result-if packing, got void if with arm drops: \{@debug.to_string(instrs[idx])}",
              )
            }
          _ => ()
        }
      }
      assert_true(
        saw_result_if && saw_drop_after_result_if,
        msg=@debug.to_string(instrs),
      )
    }
    other =>
      fail(
        "expected one defined function for dropped result-if fixture, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum preserves call-indirect prefix wrappers before allocation continuations" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (type $callee (func (param i32 i32 i32 i32) (result i32)))
      #|  (import "m" "retain" (func $retain (param i32)))
      #|  (import "m" "release" (func $release (param i32)))
      #|  (import "m" "pred" (func $pred (param i32) (result i32)))
      #|  (import "m" "alloc" (func $alloc (param i32) (result i32)))
      #|  (import "m" "tag" (func $tag (param i32 i32)))
      #|  (table 1 funcref)
      #|  (elem (i32.const 0) $callee)
      #|  (memory 1)
      #|  (func $callee (type $callee) (param i32 i32 i32 i32) (result i32)
      #|    (local.get 0))
      #|  (func (export "test") (param i32 i32 i32 i32) (result i32)
      #|    (local i32 i32 i32 i32 i32)
      #|    (block $exit
      #|      (block
      #|        (call $retain
      #|          (local.tee 4
      #|            (i32.load offset=36 align=1
      #|              (local.get 0))))
      #|        (local.set 5
      #|          (call_indirect (type $callee)
      #|            (local.get 4)
      #|            (local.get 1)
      #|            (local.get 2)
      #|            (local.get 3)
      #|            (i32.load align=1 (local.get 4))))
      #|        (call $release (local.get 4))
      #|        (if
      #|          (i32.eq
      #|            (call $pred (local.tee 6 (local.get 5)))
      #|            (i32.const 1))
      #|          (then
      #|            (local.set 7 (i32.load align=1 (local.get 6)))
      #|            (local.set 8 (local.get 7)))
      #|          (else
      #|            (local.set 8 (i32.load align=1 (local.get 6)))
      #|            (br $exit))))
      #|      (call $tag
      #|        (local.tee 7 (call $alloc (i32.const 4)))
      #|        (i32.const 257))
      #|      (i32.store align=1 (local.get 7) (local.get 8))
      #|      (return (local.get 7)))
      #|    (local.get 8))
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected call-indirect prefix wrapper vacuum success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected call-indirect prefix wrapper vacuum output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([_, @lib.Func(_, @lib.Expr(instrs))])) =>
      match instrs[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) => {
          match outer_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) => {
              let mut saw_retain_call = false
              let mut saw_call_indirect = false
              for prefix_idx = 0
                  prefix_idx < prefix_body.length()
                  prefix_idx = prefix_idx + 1 {
                match prefix_body[prefix_idx] {
                  @lib.Call(_) if !saw_call_indirect => saw_retain_call = true
                  @lib.CallIndirect(_, _) => saw_call_indirect = true
                  _ => ()
                }
              }
              if !saw_retain_call || !saw_call_indirect {
                fail(
                  "expected preserved call-indirect prefix child block to contain retain call before call_indirect, got \{@debug.to_string(prefix_body)}",
                )
              }
            }
            other =>
              fail(
                "expected Binaryen-preserved call-indirect prefix child block before allocation continuation, got \{@debug.to_string(other)}",
              )
          }
          let mut saw_allocation_continuation = false
          for idx = 1; idx < outer_body.length(); idx = idx + 1 {
            match outer_body[idx] {
              @lib.Call(_) => saw_allocation_continuation = true
              _ => ()
            }
          }
          if !saw_allocation_continuation {
            fail(
              "expected call-indirect prefix wrapper fixture to retain allocation continuation",
            )
          }
        }
        other =>
          fail(
            "expected outer continuation block for call-indirect prefix wrapper fixture, got \{@debug.to_string(other)}",
          )
      }
    other =>
      fail(
        "expected callee plus test function for call-indirect prefix wrapper fixture, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum preserves two-arg call local-set prefix wrappers before allocation continuations" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "make" (func $make (param i32 i32) (result i32)))
      #|  (import "m" "release" (func $release (param i32)))
      #|  (import "m" "pred" (func $pred (param i32) (result i32)))
      #|  (import "m" "alloc" (func $alloc (param i32) (result i32)))
      #|  (import "m" "tag" (func $tag (param i32 i32)))
      #|  (memory 1)
      #|  (func (export "test") (param i32 i32) (result i32)
      #|    (local i32 i32 i32 i32 i32)
      #|    (block $exit
      #|      (block
      #|        (block
      #|          (local.set 2 (call $make (local.get 0) (local.get 1)))
      #|          (call $release (local.get 2)))
      #|        (if
      #|          (i32.eq (call $pred (local.tee 3 (local.get 2))) (i32.const 1))
      #|          (then
      #|            (local.set 4 (i32.load align=1 (local.get 3)))
      #|            (local.set 5 (local.get 4)))
      #|          (else
      #|            (local.set 5 (i32.load align=1 (local.get 3)))
      #|            (br $exit))))
      #|      (call $tag
      #|        (local.tee 4 (call $alloc (i32.const 4)))
      #|        (i32.const 257))
      #|      (i32.store align=1 (local.get 4) (local.get 5))
      #|      (return (local.get 4)))
      #|    (local.get 5))
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail(
        "expected two-arg local-set prefix wrapper vacuum success, got \{err}",
      )
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected two-arg local-set prefix wrapper vacuum output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      match instrs[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) =>
          match outer_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_if_body)) => {
              match prefix_if_body[0] {
                @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) => {
                  let mut saw_make_call = false
                  let mut saw_local_set_after_call = false
                  for prefix_idx = 0
                      prefix_idx < prefix_body.length()
                      prefix_idx = prefix_idx + 1 {
                    match prefix_body[prefix_idx] {
                      @lib.Call(_) => saw_make_call = true
                      @lib.LocalSet(_) if saw_make_call =>
                        saw_local_set_after_call = true
                      _ => ()
                    }
                  }
                  if !saw_local_set_after_call {
                    fail(
                      "expected preserved two-arg prefix child block to contain call-fed local.set, got \{@debug.to_string(prefix_body)}",
                    )
                  }
                }
                other =>
                  fail(
                    "expected preserved two-arg local-set prefix child block before allocation continuation, got \{@debug.to_string(other)}",
                  )
              }
              match prefix_if_body[prefix_if_body.length() - 1] {
                @lib.If(@lib.VoidBlockType, _, Some(_)) => ()
                other =>
                  fail(
                    "expected preserved two-arg local-set wrapper to retain trailing branchy if, got \{@debug.to_string(other)}",
                  )
              }
            }
            other =>
              fail(
                "expected Binaryen-preserved two-arg local-set prefix wrapper before allocation continuation, got \{@debug.to_string(other)}",
              )
          }
        other =>
          fail(
            "expected outer continuation block for two-arg local-set prefix wrapper fixture, got \{@debug.to_string(other)}",
          )
      }
    other =>
      fail(
        "expected one defined function for two-arg local-set prefix wrapper fixture, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum preserves predicate-local continuation wrappers before loops" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "hold" (func $hold (param i32)))
      #|  (import "m" "release" (func $release (param i32)))
      #|  (import "m" "make" (func $make (param i32 i32) (result i32)))
      #|  (import "m" "alloc" (func $alloc (param i32) (result i32)))
      #|  (memory 1)
      #|  (func (param $p i32) (param $q i32)
      #|    (local $flag i32) (local $tmp i32) (local $out i32)
      #|    (loop $loop
      #|      (block $exit
      #|        (block
      #|          (block
      #|            nop nop nop nop nop nop nop nop
      #|            nop nop nop nop nop nop nop nop
      #|            (if (i32.le_s (local.get $p) (i32.const 4096))
      #|              (then
      #|                (local.set $flag
      #|                  (i32.lt_s
      #|                    (i32.load align=1 (local.get $q))
      #|                    (i32.const 64))))
      #|              (else
      #|                (local.set $flag (i32.const 0))))
      #|          )
      #|          nop
      #|          (if (local.get $flag)
      #|            (then
      #|              (call $hold
      #|                (local.tee $tmp (i32.load align=1 (local.get $q))))
      #|              (local.set $out
      #|                (call $make (local.get $tmp) (local.get $p)))
      #|              (call $release (local.get $tmp))
      #|              (if (i32.eqz (i32.load align=1 (local.get $out)))
      #|                (then
      #|                  (call $release (local.get $out))
      #|                  (br $exit)))
      #|              (local.set $p
      #|                (i32.add (local.get $p) (i32.const 1)))
      #|              (br $loop))
      #|            (else
      #|              (call $release (local.get $q))))
      #|        )
      #|      )
      #|    )
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected predicate-local continuation vacuum success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected predicate-local continuation vacuum output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      match instrs[0] {
        @lib.Loop(@lib.VoidBlockType, @lib.Expr(loop_body)) =>
          match loop_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(exit_body)) =>
              match exit_body[0] {
                @lib.Block(@lib.VoidBlockType, @lib.Expr(wrapper_body)) => {
                  match wrapper_body[0] {
                    @lib.Block(_, _) =>
                      fail(
                        "expected inner predicate-only child block to be cleaned, got nested block \{@debug.to_string(wrapper_body[0])}",
                      )
                    _ => ()
                  }
                  let mut if_count = 0
                  for idx = 0; idx < wrapper_body.length(); idx = idx + 1 {
                    match wrapper_body[idx] {
                      @lib.If(@lib.VoidBlockType, _, _) =>
                        if_count = if_count + 1
                      _ => ()
                    }
                  }
                  @debug.assert_eq(if_count, 2)
                  match wrapper_body[wrapper_body.length() - 1] {
                    @lib.If(@lib.VoidBlockType, _, Some(_)) => ()
                    other =>
                      fail(
                        "expected preserved predicate wrapper to end with the branchy continuation if, got \{@debug.to_string(other)}",
                      )
                  }
                }
                other =>
                  fail(
                    "expected Binaryen-preserved predicate-local continuation wrapper, got \{@debug.to_string(other)}",
                  )
              }
            other =>
              fail(
                "expected exit block for predicate-local continuation fixture, got \{@debug.to_string(other)}",
              )
          }
        other =>
          fail(
            "expected loop for predicate-local continuation fixture, got \{@debug.to_string(other)}",
          )
      }
    other =>
      fail(
        "expected one defined function for predicate-local continuation fixture, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum preserves tag-20 local-set call prefix block before parent continuation" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "env" "make" (func $make (param i32 i32) (result i32)))
      #|  (import "env" "release" (func $release (param i32)))
      #|  (memory 1)
      #|  (func (param $p i32) (local $a i32) (local $b i32) (local $c i32) (local $d i32) (local $x i32)
      #|    (block $outer
      #|      (local.set $x (i32.sub (local.get $p) (i32.const 0)))
      #|      (block $parent
      #|        (block
      #|          (local.set $a (i32.const 0))
      #|          (drop (call $make (i32.const 0) (local.get $x)))
      #|          (local.set $d (call $make (i32.const 0) (local.get $p)))
      #|          (if (i32.eq (i32.const 0) (i32.const 20))
      #|            (then
      #|              (call $release (local.get $a))
      #|              (if (i32.eq (local.get $b) (i32.const 0))
      #|                (then)
      #|                (else
      #|                  (call $release (i32.const 0))
      #|                  (call $release (local.get $p))
      #|                  (br $parent)
      #|                )
      #|              )
      #|            )
      #|            (else
      #|              (call $release (local.get $c))
      #|              (call $release (local.get $b))
      #|              (call $release (local.get $p))
      #|              (call $release (i32.const 0))
      #|              (br $parent)
      #|            )
      #|          )
      #|        )
      #|        (i32.store align=1 (i32.const 0) (i32.const 0))
      #|      )
      #|    )
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected tag-20 prefix preservation vacuum success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tag-20 prefix preservation vacuum output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      match instrs[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body)) => {
          let mut saw_prefix_block = false
          for instr in parent_body {
            match instr {
              @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) => {
                saw_prefix_block = true
                let check_body = match prefix_body[0] {
                  @lib.Block(@lib.VoidBlockType, @lib.Expr(child_body)) =>
                    child_body
                  _ => prefix_body
                }
                match check_body[0] {
                  @lib.I32Const(@lib.I32(value)) => @debug.assert_eq(value, 0)
                  other =>
                    fail(
                      "expected preserved tag-20 prefix child block to start with local.set value, got \{@debug.to_string(other)}",
                    )
                }
                match check_body[check_body.length() - 1] {
                  @lib.If(@lib.VoidBlockType, _, Some(_)) => ()
                  other =>
                    fail(
                      "expected preserved tag-20 prefix child block to end with branchy void if, got \{@debug.to_string(other)}",
                    )
                }
              }
              _ => ()
            }
          }
          if !saw_prefix_block {
            fail(
              "expected Binaryen-preserved tag-20 prefix child block before store continuation, got \{@debug.to_string(parent_body)}",
            )
          }
        }
        other =>
          fail(
            "expected parent block for tag-20 prefix preservation, got \{@debug.to_string(other)}",
          )
      }
    other =>
      fail(
        "expected single function for tag-20 prefix preservation, got \{@debug.to_string(other)}",
      )
  }
}

///|
fn optimize_test_body_is_f340_tag_load_dispatch(
  body : Array[@lib.Instruction],
) -> Bool {
  let mut end = body.length()
  if end > 0 && body[end - 1] is @lib.Unreachable {
    end = end - 1
  }
  if end < 6 {
    return false
  }
  match body[end - 1] {
    @lib.If(@lib.VoidBlockType, _, Some(_)) => ()
    _ => return false
  }
  if !(body[end - 2] is @lib.I32Eq) {
    return false
  }
  match body[end - 3] {
    @lib.I32Const(@lib.I32(11)) => ()
    _ => return false
  }
  let mut saw_call = false
  let mut saw_load = false
  let mut saw_tee = false
  for idx = 0; idx + 1 < end; idx = idx + 1 {
    match body[idx] {
      @lib.Call(_) => saw_call = true
      @lib.I32Load(_) => saw_load = true
      @lib.LocalTee(_) => saw_tee = true
      _ => ()
    }
  }
  saw_call && saw_load && saw_tee
}

///|
fn optimize_test_instrs_have_nested_f340_tag_dispatch_wrapper(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.Block(@lib.VoidBlockType, @lib.Expr(body)) => {
        if body.length() > 0 {
          match body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(child_body)) =>
              if optimize_test_body_is_f340_tag_load_dispatch(child_body) {
                return true
              }
            _ => ()
          }
        }
        if optimize_test_instrs_have_nested_f340_tag_dispatch_wrapper(body) {
          return true
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if optimize_test_instrs_have_nested_f340_tag_dispatch_wrapper(body) {
          return true
        }
      @lib.If(_, then_body, else_body) => {
        if optimize_test_instrs_have_nested_f340_tag_dispatch_wrapper(then_body) {
          return true
        }
        match else_body {
          Some(body) =>
            if optimize_test_instrs_have_nested_f340_tag_dispatch_wrapper(body) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
  }
  false
}

///|
test "vacuum flattens f340 branchy tag-load dispatch singleton wrappers" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (memory 1)
      #|  (func $make (result i32) (i32.const 0))
      #|  (func $size (param i32) (result i32) (i32.const 1))
      #|  (func $release (param i32))
      #|  (func (export "f") (param $x i32) (result i32)
      #|    (local $tag i32) (local $ptr i32) (local $a i32) (local $flag i32)
      #|    (block $exit
      #|      (block $fail
      #|        (block $case2
      #|          (block $case1
      #|            (block
      #|              (block
      #|                (if
      #|                  (i32.eq
      #|                    (local.tee $tag
      #|                      (i32.load align=1
      #|                        (local.tee $ptr (call $make))))
      #|                    (i32.const 11))
      #|                  (then
      #|                    (local.set $a (i32.load offset=4 align=1 (local.get $ptr)))
      #|                    (call $release (local.get $ptr))
      #|                    (if
      #|                      (i32.eqz (i32.eq (call $size (local.get $a)) (local.get $x)))
      #|                      (then (br $fail))))
      #|                  (else
      #|                    (if (i32.eq (local.get $tag) (i32.const 2))
      #|                      (then
      #|                        (local.set $a (i32.load offset=8 align=1 (local.get $ptr)))
      #|                        (br $case1))
      #|                      (else
      #|                        (call $release (local.get $ptr))
      #|                        (br $fail)))))
      #|                (unreachable))
      #|              (if (call $size (local.get $x))
      #|                (then (local.set $flag (i32.const 1)))
      #|                (else (local.set $flag (i32.const 0))))
      #|              (if (local.get $flag)
      #|                (then (i32.store align=1 (i32.const 0) (i32.const 1)))
      #|                (else (br $exit))))))))
      #|    (local.get $a))
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) => fail("expected f340 tag-load vacuum success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected f340 tag-load vacuum output to validate, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([_, _, _, @lib.Func(_, @lib.Expr(instrs))])) =>
      if optimize_test_instrs_have_nested_f340_tag_dispatch_wrapper(instrs) {
        fail(
          "expected Binaryen-like f340 tag-load dispatch singleton wrapper flattening",
        )
      }
    other =>
      fail(
        "expected three helper functions plus f340 tag-load fixture, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum flattens binary-lowered f305 load-linked local-set-call prefix child block" {
  // Binary-lowered 2211-byte repro from the current slot23 `defined=305`
  // residual at `.tmp/vacuum-f305-current/working-f305-firsthunk-clean-localsetcall-cont12-tight-timeout.wasm`.
  // WAT probes have normalized away the full-context difference, so keep this
  // binary seed as red-first coverage until a smaller source-backed fixture is
  // available. Binaryen flattens the child block around the const-arg
  // `local.set(call ...)` prefix before the load-linked branchy `if`; current
  // Starshine still keeps that extra block.
  let input = match
    @binary.decode_module(
      Bytes::from_array([
        0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x13, 0x04, 0x60, 0x01,
        0x7f, 0x00, 0x60, 0x02, 0x7f, 0x7f, 0x01, 0x7f, 0x60, 0x00, 0x00, 0x60, 0x01,
        0x7f, 0x01, 0x7f, 0x02, 0x31, 0x03, 0x03, 0x65, 0x6e, 0x76, 0x09, 0x66, 0x69,
        0x6d, 0x70, 0x6f, 0x72, 0x74, 0x24, 0x31, 0x00, 0x00, 0x03, 0x65, 0x6e, 0x76,
        0x09, 0x66, 0x69, 0x6d, 0x70, 0x6f, 0x72, 0x74, 0x24, 0x32, 0x00, 0x01, 0x03,
        0x65, 0x6e, 0x76, 0x09, 0x66, 0x69, 0x6d, 0x70, 0x6f, 0x72, 0x74, 0x24, 0x33,
        0x00, 0x02, 0x03, 0x02, 0x01, 0x03, 0x05, 0x03, 0x01, 0x00, 0x04, 0x08, 0x01,
        0x02, 0x0c, 0x02, 0x9a, 0x03, 0x0a, 0x3a, 0x01, 0x38, 0x01, 0xd0, 0x05, 0x7f,
        0x41, 0x01, 0x04, 0x40, 0x02, 0x40, 0x02, 0x40, 0x02, 0x40, 0x02, 0x40, 0x41,
        0x00, 0x41, 0x00, 0x10, 0x01, 0x21, 0x88, 0x01, 0x20, 0x88, 0x01, 0x22, 0x0c,
        0x28, 0x00, 0x00, 0x41, 0x14, 0x46, 0x04, 0x40, 0x01, 0x05, 0x00, 0x0b, 0x0b,
        0x0b, 0x0c, 0x01, 0x0b, 0x00, 0x0b, 0x00, 0x05, 0x01, 0x0b, 0x41, 0x00, 0x0b,
        0x0b, 0x84, 0x10, 0x9a, 0x03, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41,
        0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00,
        0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00,
        0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00,
        0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b, 0x00, 0x00, 0x41, 0x00, 0x0b,
        0x00,
      ]),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected binary-lowered f305 fixture to decode, got \{err}")
  }
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected binary-lowered f305 vacuum success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected binary-lowered f305 vacuum output to validate, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      match instrs[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) =>
          match outer_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(middle_body)) =>
              match middle_body[0] {
                @lib.Block(@lib.VoidBlockType, @lib.Expr(parent_body)) => {
                  match parent_body[0] {
                    @lib.Block(_, _) =>
                      fail(
                        "expected Binaryen-flattened f305 local-set-call prefix; got an extra child block",
                      )
                    @lib.I32Const(@lib.I32(value)) => @debug.assert_eq(value, 0)
                    other =>
                      fail(
                        "expected f305 flattened local-set-call prefix to start with const arg, got \{@debug.to_string(other)}",
                      )
                  }
                  let mut saw_local_set_136 = false
                  let mut saw_following_if = false
                  for idx = 0; idx < parent_body.length(); idx = idx + 1 {
                    match parent_body[idx] {
                      @lib.LocalSet(@lib.LocalIdx(raw)) =>
                        if raw.reinterpret_as_int() == 136 {
                          saw_local_set_136 = true
                        }
                      @lib.If(@lib.VoidBlockType, _, _) if saw_local_set_136 =>
                        saw_following_if = true
                      _ => ()
                    }
                  }
                  if !saw_local_set_136 || !saw_following_if {
                    fail(
                      "expected f305 flattened prefix to keep local.set 136 before the following branchy if",
                    )
                  }
                }
                other =>
                  fail(
                    "expected f305 parent block before branchy continuation, got \{@debug.to_string(other)}",
                  )
              }
            other =>
              fail("expected f305 middle block, got \{@debug.to_string(other)}")
          }
        other =>
          fail("expected f305 outer block, got \{@debug.to_string(other)}")
      }
    other =>
      fail(
        "expected one defined function for binary-lowered f305 fixture, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum flattens branchy refcount if wrappers before allocation continuations" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "classify" (func $classify (param i32) (result i32)))
      #|  (import "m" "retain" (func $retain (param i32)))
      #|  (import "m" "release" (func $release (param i32)))
      #|  (import "m" "make" (func $make (param i32 i32 i32 i32 i32) (result i32)))
      #|  (import "m" "alloc" (func $alloc (param i32) (result i32)))
      #|  (memory 1)
      #|  (func (param i32 i32) (result i32) (local i32 i32 i32 i32 i32 i32)
      #|    (block $outer
      #|      (block $exit
      #|        (block
      #|          nop nop nop nop nop nop nop nop
      #|          nop nop nop nop nop nop nop nop
      #|          (if
      #|            (local.tee 2
      #|              (call $classify
      #|                (local.tee 3 (i32.load align=1 (local.get 0)))))
      #|            (then
      #|              (call $retain (local.get 3))
      #|              (local.set 4 (local.get 3))
      #|              (br $exit)
      #|            )
      #|            (else
      #|              (block $made
      #|                (block $skip
      #|                  (call $retain (local.get 3))
      #|                  (local.set 5
      #|                    (call $make
      #|                      (local.get 0)
      #|                      (local.get 1)
      #|                      (local.get 2)
      #|                      (local.get 3)
      #|                      (i32.const 9)))
      #|                  (call $release (local.get 3))
      #|                  (if
      #|                    (i32.eq
      #|                      (call $classify (local.tee 6 (local.get 5)))
      #|                      (i32.const 1))
      #|                    (then
      #|                      (call $release (local.get 6))
      #|                    )
      #|                    (else
      #|                      (local.set 4 (i32.load align=1 (local.get 6)))
      #|                      (br $skip)
      #|                    )
      #|                  )
      #|                  (br $made)
      #|                )
      #|                (local.set 7 (call $alloc (i32.const 4)))
      #|                (i32.store align=1 (local.get 7) (local.get 4))
      #|                (return (local.get 7))
      #|              )
      #|            )
      #|          )
      #|        )
      #|      )
      #|      (return (local.get 4))
      #|    )
      #|    (i32.const 0)
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected branchy refcount wrapper vacuum success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected branchy refcount wrapper vacuum output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      match instrs[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) =>
          match outer_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(exit_body)) => {
              let mut seen_if = false
              let mut i = 0
              while i < exit_body.length() && not(seen_if) {
                match exit_body[i] {
                  @lib.Block(_, _) =>
                    fail(
                      "expected Binaryen-matching branchy refcount if wrapper to flatten, got extra block",
                    )
                  @lib.If(@lib.VoidBlockType, _, Some(_)) => seen_if = true
                  _ => ()
                }
                i = i + 1
              }
              if not(seen_if) {
                fail(
                  "expected flattened branchy refcount wrapper to contain the branchy if",
                )
              }
            }
            other =>
              fail(
                "expected exit block for branchy refcount wrapper fixture, got \{@debug.to_string(other)}",
              )
          }
        other =>
          fail(
            "expected outer block for branchy refcount wrapper fixture, got \{@debug.to_string(other)}",
          )
      }
    other =>
      fail(
        "expected one defined function for branchy refcount wrapper fixture, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum preserves local-set-leading prefix blocks before void ifs" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "side" (func $side (param i32)))
      #|  (import "m" "make" (func $make (param i32) (result i32)))
      #|  (import "m" "pred" (func $pred (param i32) (result i32)))
      #|  (func (param i32) (local i32 i32)
      #|    (block
      #|      (block
      #|        (block
      #|          (block
      #|            nop nop nop nop nop nop nop nop
      #|            nop nop nop nop nop nop nop nop
      #|            (local.set 1 (call $make (local.get 0)))
      #|            (call $side (local.get 1))
      #|          )
      #|          (if (i32.eq (call $pred (local.get 1)) (i32.const 1))
      #|            (then
      #|              (local.set 2 (local.get 1))
      #|              (br 3)
      #|            )
      #|          )
      #|        )
      #|      )
      #|      (call $side (i32.const 7))
      #|    )
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected local-set-leading prefix vacuum success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected local-set-leading prefix vacuum output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::block(
                  @lib.BlockType::void_(),
                  @lib.Expr::new([
                    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                    @lib.Instruction::call(@lib.FuncIdx::new(1U)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
                    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
                  ]),
                ),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::call(@lib.FuncIdx::new(2U)),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::i32_eq(),
                @lib.Instruction::if_(
                  @lib.BlockType::void_(),
                  [
                    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
                    @lib.Instruction::br(@lib.LabelIdx::new(2U)),
                  ],
                  None,
                ),
              ]),
            ),
            @lib.Instruction::i32_const(@lib.I32::new(7)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
          ]),
        ),
      ])
    other =>
      fail(
        "expected local-set-leading prefix block before void if to stay wrapped, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum preserves multi-local prefix child blocks before void ifs" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "hold" (func $hold (param i32)))
      #|  (import "m" "release" (func $release (param i32)))
      #|  (import "m" "make1" (func $make1 (param i32) (result i32)))
      #|  (import "m" "make4" (func $make4 (param i32 i32 i32 i32) (result i32)))
      #|  (import "m" "pred" (func $pred (param i32) (result i32)))
      #|  (memory 1)
      #|  (func (param i32 i32) (local i32 i32 i32 i32 i32 i32 i32)
      #|    (block
      #|      (block
      #|        (block
      #|          nop nop nop nop nop nop nop nop
      #|          nop nop nop nop nop nop nop nop
      #|          (local.set 2
      #|            (i32.load offset=32 align=1 (local.get 0)))
      #|          (call $hold
      #|            (local.tee 3
      #|              (i32.load offset=28 align=1 (local.get 0))))
      #|          (call $hold (local.get 2))
      #|          (local.set 4 (call $make1 (local.get 3)))
      #|          (call $release (local.get 3))
      #|          (local.set 5
      #|            (call $make4
      #|              (local.get 1)
      #|              (local.get 2)
      #|              (local.get 4)
      #|              (i32.const 23344)))
      #|          (call $release (local.get 1))
      #|          (call $release (local.get 2))
      #|          (if (i32.eq (call $pred (local.tee 6 (local.get 5))) (i32.const 1))
      #|            (then
      #|              (local.set 7 (i32.load align=1 (local.get 6)))
      #|              (call $release (local.get 6))
      #|              (local.set 8 (local.get 7))
      #|            )
      #|            (else
      #|              (local.set 8 (local.get 6))
      #|              (br 2)
      #|            )
      #|          )
      #|        )
      #|        (call $hold (i32.const 7))
      #|      )
      #|    )
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail(
        "expected multi-local prefix preservation vacuum success, got \{err}",
      )
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected multi-local prefix preservation vacuum output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      match instrs[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) => {
          @debug.assert_eq(outer_body.length(), 3)
          match outer_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(prefix_body)) => {
              match prefix_body[0] {
                @lib.LocalGet(@lib.LocalIdx(raw)) =>
                  @debug.assert_eq(raw.reinterpret_as_int(), 0)
                other =>
                  fail(
                    "expected preserved multi-local prefix block to start with lowered local.get 0, got \{@debug.to_string(other)}",
                  )
              }
              match prefix_body[prefix_body.length() - 1] {
                @lib.If(@lib.VoidBlockType, _, Some(_)) => ()
                other =>
                  fail(
                    "expected preserved multi-local prefix block to end with a void if, got \{@debug.to_string(other)}",
                  )
              }
            }
            other =>
              fail(
                "expected multi-local prefix child block to stay wrapped before following call, got \{@debug.to_string(other)}",
              )
          }
          match outer_body[1] {
            @lib.I32Const(@lib.I32(value)) => @debug.assert_eq(value, 7)
            other =>
              fail(
                "expected preserved multi-local prefix block to be followed by the parent continuation call argument, got \{@debug.to_string(other)}",
              )
          }
          match outer_body[2] {
            @lib.Call(@lib.FuncIdx(raw)) =>
              @debug.assert_eq(raw.reinterpret_as_int(), 0)
            other =>
              fail(
                "expected preserved multi-local prefix block to be followed by the parent continuation call, got \{@debug.to_string(other)}",
              )
          }
        }
        other =>
          fail(
            "expected outer wrapper for multi-local prefix preservation, got \{@debug.to_string(other)}",
          )
      }
    other =>
      fail(
        "expected single function for multi-local prefix preservation, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum flattens extra inner multi-local prefix wrappers before outer if chains" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (import "m" "hold" (func $hold (param i32)))
      #|  (import "m" "release" (func $release (param i32)))
      #|  (import "m" "make1" (func $make1 (param i32) (result i32)))
      #|  (import "m" "make4" (func $make4 (param i32 i32 i32 i32) (result i32)))
      #|  (import "m" "pred" (func $pred (param i32) (result i32)))
      #|  (import "m" "alloc" (func $alloc (param i32 i32)))
      #|  (import "m" "malloc" (func $malloc (param i32) (result i32)))
      #|  (memory 1)
      #|  (func (param $0 i32) (param $1 i32) (result i32)
      #|    (local $2 i32) (local $3 i32) (local $4 i32) (local $5 i32) (local $6 i32)
      #|    (local $7 i32) (local $8 i32) (local $9 i32) (local $10 i32) (local $11 i32)
      #|    (local $12 i32) (local $13 i32) (local $14 i32) (local $15 i32) (local $16 i32)
      #|    (block $outer
      #|      (block $middle
      #|        (block
      #|          (block
      #|            nop nop nop nop
      #|            nop nop nop nop
      #|            (local.set $2 (i32.load offset=32 align=1 (local.get $0)))
      #|            (call $hold (local.tee $3 (i32.load offset=28 align=1 (local.get $0))))
      #|            (call $hold (local.get $2))
      #|            (local.set $4 (call $make1 (local.get $3)))
      #|            (call $release (local.get $3))
      #|            (local.set $5 (call $make4 (local.get $1) (local.get $2) (local.get $4) (i32.const 23344)))
      #|            (call $release (local.get $1))
      #|            (call $release (local.get $2))
      #|            (if (i32.eq (call $pred (local.tee $6 (local.get $5))) (i32.const 1))
      #|              (then
      #|                (local.set $7 (i32.load align=1 (local.get $6)))
      #|                (call $release (local.get $6))
      #|                (local.set $8 (local.get $7))
      #|              )
      #|              (else
      #|                (local.set $16 (local.get $6))
      #|                (local.set $10 (local.get $16))
      #|                (br $middle)
      #|              )
      #|            )
      #|          )
      #|        )
      #|        (local.set $9 (local.get $8))
      #|        (br $outer)
      #|      )
      #|      (call $alloc
      #|        (local.tee $11 (call $malloc (i32.const 4)))
      #|        (i32.const 256))
      #|      (i32.store align=1 (local.get $11) (local.get $10))
      #|      (return (local.get $11))
      #|    )
      #|    (local.set $12 (call $make1 (local.get $9)))
      #|    (if (i32.eq (call $pred (local.get $1)) (i32.const 60))
      #|      (then
      #|        (local.set $13 (call $make1 (local.get $12)))
      #|        (call $release (local.get $12))
      #|        (call $alloc (local.tee $14 (call $malloc (i32.const 4))) (i32.const 257))
      #|        (i32.store align=1 (local.get $14) (local.get $13))
      #|        (local.set $15 (local.get $14))
      #|      )
      #|      (else
      #|        (if (i32.eq (call $pred (local.get $1)) (i32.const 61))
      #|          (then
      #|            (local.set $13 (call $make1 (local.get $12)))
      #|            (call $release (local.get $12))
      #|            (call $alloc (local.tee $14 (call $malloc (i32.const 4))) (i32.const 257))
      #|            (i32.store align=1 (local.get $14) (local.get $13))
      #|            (local.set $15 (local.get $14))
      #|          )
      #|          (else
      #|            (call $release (local.get $12))
      #|            (call $alloc (local.tee $14 (call $malloc (i32.const 4))) (i32.const 256))
      #|            (i32.store align=1 (local.get $14) (i32.const 157976))
      #|            (local.set $15 (local.get $14))
      #|          )
      #|        )
      #|      )
      #|    )
      #|    (return (local.get $15))
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected extra-inner multi-local prefix vacuum success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected extra-inner multi-local prefix vacuum output to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      match instrs[0] {
        @lib.Block(@lib.VoidBlockType, @lib.Expr(outer_body)) =>
          match outer_body[0] {
            @lib.Block(@lib.VoidBlockType, @lib.Expr(middle_body)) =>
              match middle_body[0] {
                @lib.Block(@lib.VoidBlockType, @lib.Expr(child_body)) =>
                  match child_body[0] {
                    @lib.LocalGet(@lib.LocalIdx(raw)) =>
                      @debug.assert_eq(raw.reinterpret_as_int(), 0)
                    @lib.Block(_, _) =>
                      fail(
                        "expected extra inner multi-local prefix wrapper to be flattened before the middle/outer continuation, got another block",
                      )
                    other =>
                      fail(
                        "expected flattened extra-inner multi-local prefix to start with lowered local.get 0, got \{@debug.to_string(other)}",
                      )
                  }
                other =>
                  fail(
                    "expected middle continuation child block for extra-inner prefix test, got \{@debug.to_string(other)}",
                  )
              }
            other =>
              fail(
                "expected outer middle block for extra-inner prefix test, got \{@debug.to_string(other)}",
              )
          }
        other =>
          fail(
            "expected outer block for extra-inner prefix test, got \{@debug.to_string(other)}",
          )
      }
    other =>
      fail(
        "expected single function for extra-inner prefix test, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum raw-unwraps terminal unreachable block wrappers with outer branches" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (func (param i32) (local i32)
      #|    nop nop nop nop nop nop nop nop
      #|    nop nop nop nop nop nop nop nop
      #|    (loop
      #|      (block
      #|        (block
      #|          (block
      #|            (br_if 2 (local.get 0))
      #|            (local.set 1 (i32.const 1))
      #|            (br 3)
      #|          )
      #|          unreachable
      #|        )
      #|        unreachable
      #|      )
      #|    )
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) => fail("expected vacuum pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected terminal-wrapper output to validate, got \{err}")
  }
  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.Loop(
                  @lib.VoidBlockType,
                  @lib.Expr(
                    [
                      @lib.Block(
                        @lib.VoidBlockType,
                        @lib.Expr(
                          [
                            @lib.Block(@lib.VoidBlockType, @lib.Expr(body)),
                            @lib.Unreachable,
                          ]
                        )
                      ),
                    ]
                  )
                ),
              ]
            )
          ),
        ]
      )
    ) =>
      @debug.assert_eq(body, [
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::br_if(@lib.LabelIdx::new(1U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::br(@lib.LabelIdx::new(2U)),
      ])
    other =>
      fail(
        "expected one terminal-unreachable wrapper removed with rebased branches, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum raw-unwraps dense nop blocks with outer branches" {
  let input = pass_test_module_from_wat(
    (
      #|(module
      #|  (func (local i32)
      #|    (block
      #|      (block
      #|        nop nop nop nop nop nop nop nop
      #|        nop nop nop nop nop nop nop nop
      #|        (if (i32.const 1)
      #|          (then
      #|            (br 2)
      #|          )
      #|        )
      #|      )
      #|      (i32.const 9)
      #|      (local.set 0)
      #|    )
      #|  )
      #|)
    ),
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) => fail("expected vacuum pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected raw block-unwrapped output to validate, got \{err}")
  }
  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr([@lib.Block(@lib.VoidBlockType, @lib.Expr(instrs))])
          ),
        ]
      )
    ) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [@lib.Instruction::br(@lib.LabelIdx::new(1U))],
          None,
        ),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      ])
    other =>
      fail(
        "expected outer block with rebased branch after raw vacuum, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum matches Binaryen empty function nop canonicalization" {
  let input = pass_test_module_from_wat("(module (func))")
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) => fail("expected vacuum pipeline success, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [@lib.Instruction::nop()])
    other =>
      fail(
        "expected vacuumed empty function to contain one nop, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum unwraps block that only contains unreachable" {
  let input = pass_test_module_from_wat("(module (func block unreachable end))")
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) => fail("expected vacuum pipeline success, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr([instr]))])) =>
      match instr {
        @lib.Instruction::Unreachable => ()
        other => fail("expected unwrapped unreachable, got \{other}")
      }
    other =>
      fail(
        "expected single vacuumed unreachable output, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "repeated vacuum slots keep empty cleanup byte-stable" {
  let input = pass_test_module_from_wat(
    "(module (func nop block unreachable end nop))",
  )
  let once = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) => fail("expected first vacuum cleanup success, got \{err}")
  }
  let twice = match
    run_hot_pipeline(once, HotPipelineOptions::new(), ["vacuum"]) {
    Ok(mod) => mod
    Err(err) => fail("expected second vacuum cleanup success, got \{err}")
  }
  match @validate.validate_module(twice) {
    Ok(_) => ()
    Err(err) => fail("expected repeated-vacuum module to validate, got \{err}")
  }
  match twice.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr([instr]))])) =>
      match instr {
        @lib.Instruction::Unreachable => ()
        other =>
          fail(
            "expected repeated vacuum to leave only unreachable, got \{other}",
          )
      }
    other =>
      fail(
        "expected single repeated-vacuum function output, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum repeated-slot matrix drops detached pure residues" {
  let input = pass_test_module_from_wat(
    "(module (func (local i32) (drop (i32.add (i32.const 1) (i32.const 2))) nop (local.set 0 (i32.const 4)) nop))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["vacuum", "vacuum"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected repeated vacuum residue cleanup success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected residue-cleaned module to validate, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(instrs))])) =>
      @debug.assert_eq(instrs, [
        @lib.Instruction::i32_const(@lib.I32(4)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      ])
    other =>
      fail(
        "expected single residue-cleaned function output, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum uses raw preclean for nop-heavy call-drop debris" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (func $side (result i32) (i32.const 7))
      #|   (func
      #|     (drop (call $side))
      #|     nop nop nop nop nop nop nop nop
      #|     nop nop nop nop nop nop nop nop
      #|     nop nop nop nop nop nop nop nop))
      #|
    ),
  )
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["vacuum"],
    ) {
    Ok(mod) => mod
    Err(err) => fail("expected nop-heavy vacuum cleanup success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[vacuum]:skip-raw reason=raw-vacuum-preclean")
    }),
    msg=trace.to_string(),
  )
  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [_, @lib.Func(_, @lib.Expr([@lib.Call(@lib.FuncIdx(idx)), @lib.Drop]))]
      )
    ) => @debug.assert_eq(idx, 0U)
    other =>
      fail(
        "expected raw vacuum to preserve call drop and remove nop debris, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "vacuum uses raw preclean for branchy structured write debris" {
  let input = pass_test_module_from_wat(
    (
      #| (module
      #|   (func (param i32) (result i32) (local i32)
      #|     (block
      #|       (block
      #|         nop
      #|         (local.get 0)
      #|         (br_table 0 1))
      #|       (i32.const 1)
      #|       (local.set 1)
      #|       (br 0))
      #|     nop
      #|     (local.get 1)))
      #|
    ),
  )
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["vacuum"],
    ) {
    Ok(mod) => mod
    Err(err) => fail("expected branchy vacuum cleanup success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[vacuum]:skip-raw reason=raw-vacuum-preclean")
    }),
    msg=trace.to_string(),
  )
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected branchy raw-vacuum module to validate, got \{err}")
  }
}

///|
test "run_hot_pipeline emits trace markers for hot passes" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) nop i32.const 9))",
  )
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["vacuum"],
    ) {
    Ok(mod) => mod
    Err(err) => fail("expected traced hot pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected traced module to validate, got \{err}")
  }
  assert_true(
    trace.any(fn(line) { line.contains("pass[vacuum]:funcs count=1 changed=1") }),
  )
  assert_false(trace.any(fn(line) { line.contains("pass[vacuum]:start") }))
  assert_false(trace.any(fn(line) { line.contains("pass[vacuum]:done") }))
}

///|
test "run_hot_pipeline accepts remove-unused-names as an active hot pass" {
  let input = pass_test_module_from_wat(
    "(module (func block block nop end end))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["remove-unused-names"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected remove-unused-names pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected remove-unused-names module to validate, got \{err}")
  }
}

///|
test "run_hot_pipeline accepts tuple-optimization as an active hot pass" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) (local i32 i32 i32) block (result i32 i32 i32) i32.const 10 i32.const 20 i32.const 30 end local.set 2 local.set 1 local.set 0 local.get 0))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["tuple-optimization"]) {
    Ok(mod) => mod
    Err(err) => fail("expected tuple-optimization pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected tuple-optimization module to validate, got \{err}")
  }
}

///|
test "run_hot_pipeline keeps tuple-optimization as a no-op on scalar-only input" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) (local i32) i32.const 5 local.set 0 local.get 0))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["tuple-optimization"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected scalar-only tuple-optimization success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected scalar-only tuple-optimization module to validate, got \{err}",
      )
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(locals, @lib.Expr(instrs))])) => {
      @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
      @debug.assert_eq(instrs, [
        @lib.Instruction::i32_const(@lib.I32(5)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ])
    }
    other =>
      fail(
        "expected scalar-only tuple-optimization single-function output, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "run_hot_pipeline lowers scrambled tuple copy carriers through a typed multivalue block" {
  let input = pass_test_module_from_wat(
    "(module (type (func (param i32 i32) (result i32 i32 i32))) (type (func (param i32 i32 i32) (result i32))) (import \"env\" \"tri\" (func (type 0))) (import \"env\" \"show\" (func (type 1))) (func (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32) i32.const 42 i32.const 10000 call 0 local.set 6 local.set 5 local.tee 4 local.set 8 local.get 5 local.set 7 block (result i32 i32 i32) local.get 8 local.get 7 local.get 6 end local.set 11 local.set 9 local.set 10 local.get 10 local.get 9 local.get 11 call 1))",
  )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["tuple-optimization"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected scrambled tuple-optimization pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected scrambled tuple-optimization module to validate, got \{err}",
      )
  }
  match optimized.type_sec {
    Some(@lib.TypeSec(types)) => @debug.assert_eq(types.length(), 4)
    None => fail("expected scrambled tuple-optimization output type sec")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("(block (Type 3)"), msg=pretty)
  assert_false(
    pretty.contains("(local.set (Local 14))(local.get (Local 6))"),
    msg=pretty,
  )
}

///|
test "run_hot_pipeline stages nested branch-exit triple-result roots through split locals under tuple-optimization" {
  let source =
    #|(module
    #|  (type (func (result i32 i32 i32)))
    #|  (func (type 0) (result i32 i32 i32)
    #|    (i32.const 10)
    #|    (i32.const 20)
    #|    (i32.const 30))
    #|  (func (param i32) (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32)
    #|    (block $exit (result i32)
    #|      (if
    #|        (local.get 0)
    #|        (then
    #|          (call 0)
    #|          (local.set 4)
    #|          (local.set 3)
    #|          (local.set 2)
    #|          (local.set 7 (local.get 4))
    #|          (local.set 6 (local.get 3))
    #|          (local.set 1 (local.get 2))
    #|          (local.set 5 (local.get 7))
    #|          (local.set 0 (local.get 6))
    #|          (br $exit (local.get 5))))
    #|      (i32.const 99))))
  let input = match
    @wast.wast_to_binary_module(
      source,
      filename="tuple-temp-copy-stability.wat",
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("unexpected tuple temp copy stability fixture parse failure: \{err}")
  }
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["tuple-optimization"]) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected tuple-optimization temp-copy pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple-optimization temp-copy module to validate, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("(local.set (Local 7))"), msg=pretty)
  assert_true(pretty.contains("(local.set (Local 2))"), msg=pretty)
  assert_false(
    pretty.contains(
      "(call (Func 0))(local.set (Local 4))(local.set (Local 3))(local.set (Local 2))",
    ),
    msg=pretty,
  )
}

///|
test "optimize and shrink presets strip names while preserving non-name custom sections" {
  for pass_name in ["optimize", "shrink"] {
    let input = optimize_test_named_custom_module()
    let optimized = match
      run_hot_pipeline(input, HotPipelineOptions::new(), [pass_name]) {
      Ok(mod_) => mod_
      Err(err) => fail("expected \{pass_name} preset success, got \{err}")
    }
    @debug.assert_eq(optimized.name_sec, None)
    @debug.assert_eq(optimized.raw_name_sec_payload, None)
    @debug.assert_eq(
      optimized.custom_secs,
      optimize_test_preserved_custom_secs(),
    )
    match @validate.validate_module(optimized) {
      Ok(_) => ()
      Err(err) =>
        fail("expected \{pass_name} preset output to validate, got \{err}")
    }
  }
}

///|
test "vacuum cleans simplify-locals structured return residue in the late cleanup pair" {
  let optimized = match
    run_hot_pipeline(
      pass_test_module_from_wat(
        "(module (func (param i32) (result i32) (local i32) block $exit local.get 0 if i32.const 1 local.set 1 br $exit end i32.const 2 local.set 1 end local.get 1))",
      ),
      HotPipelineOptions::new(),
      ["simplify-locals", "vacuum"],
    ) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected simplify-locals/vacuum cleanup success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected cleanup pair module to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_false(pretty.contains("nop"), msg=pretty)
  assert_true(pretty.contains("block I32"), msg=pretty)
}

///|
fn vacuum_test_raw_func_module(
  results : Array[@lib.ValType],
  locals : @lib.Locals,
  body : Array[@lib.Instruction],
) -> @lib.Module {
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], results)),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(body))]),
  )
}

///|
test "vacuum removes pure scalar stack debris before root unreachable" {
  let optimized = match
    run_hot_pipeline(
      pass_test_module_from_wat(
        "(module (func (result i64) (local i32 f32) nop i32.const 2129477294 f32.const 0 unreachable))",
      ),
      HotPipelineOptions::new(),
      ["vacuum"],
    ) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected vacuum scalar/unreachable cleanup success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected scalar/unreachable module to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("nop"), msg=pretty)
  assert_false(pretty.contains("i32.const 2129477294"), msg=pretty)
  assert_false(pretty.contains("f32.const"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "vacuum removes pure scalar typed block debris before root unreachable" {
  let optimized = match
    run_hot_pipeline(
      vacuum_test_raw_func_module([@lib.ValType::i32()], @lib.Locals::empty(), [
        @lib.Instruction::i32_const(@lib.I32(0)),
        @lib.Instruction::block(
          @lib.BlockType::val_type(@lib.ValType::i64()),
          @lib.Expr::new([
            @lib.Instruction::f64_const(@lib.F64(0.0)),
            @lib.Instruction::unreachable_(),
          ]),
        ),
        @lib.Instruction::unreachable_(),
      ]),
      HotPipelineOptions::new(),
      ["vacuum"],
    ) {
    Ok(mod) => mod
    Err(err) =>
      fail(
        "expected vacuum typed-block/unreachable cleanup success, got \{err}",
      )
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected typed-block/unreachable module to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("i32.const I32(0)"), msg=pretty)
  assert_false(pretty.contains("f64.const"), msg=pretty)
  assert_false(pretty.contains("block I64"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "vacuum removes empty try_table debris before root unreachable" {
  let optimized = match
    run_hot_pipeline(
      vacuum_test_raw_func_module([], @lib.Locals::empty(), [
        @lib.Instruction::f32_const(@lib.F32(0.0)),
        @lib.Instruction::try_table(
          @lib.BlockType::void_(),
          [
            @lib.Catch::all(@lib.LabelIdx::new(0U)),
            @lib.Catch::all(@lib.LabelIdx::new(0U)),
          ],
          @lib.Expr::new([]),
        ),
        @lib.Instruction::unreachable_(),
      ]),
      HotPipelineOptions::new(),
      ["vacuum"],
    ) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected vacuum try_table/unreachable cleanup success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected try_table/unreachable module to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("f32.const"), msg=pretty)
  assert_false(pretty.contains("try_table"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "vacuum roundtrips dead simd prefixes before unreachable" {
  let optimized = match
    run_hot_pipeline(
      pass_test_module_from_wat(
        "(module (func (export \"f\") v128.const i32x4 1 2 3 4 i64x2.extend_low_i32x4_s i8x16.popcnt i64x2.extend_high_i32x4_u unreachable))",
      ),
      HotPipelineOptions::new(),
      ["vacuum"],
    ) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected vacuum simd/unreachable roundtrip success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected simd/unreachable module to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i64x2.extend_low_i32x4s"), msg=pretty)
  assert_true(pretty.contains("i8x16.popcnt"), msg=pretty)
  assert_true(pretty.contains("i64x2.extend_high_i32x4u"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "vacuum roundtrips top-level try_table catches that target the implicit function label" {
  let optimized = match
    run_hot_pipeline(
      pass_test_module_from_wat(
        "(module (func (export \"f\") try_table (catch_all 0) end))",
      ),
      HotPipelineOptions::new(),
      ["vacuum"],
    ) {
    Ok(mod) => mod
    Err(err) =>
      fail("expected top-level try_table roundtrip success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected top-level try_table module to validate, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("try_table"), msg=pretty)
  assert_true(pretty.contains("catch_all (Label 0)"), msg=pretty)
}

///|
test "remove-unused-names can clean up stale labels exposed by remove-unused-brs" {
  let optimized = match
    run_hot_pipeline(
      pass_test_module_from_wat("(module (func block block br 1 end end))"),
      HotPipelineOptions::new(),
      ["remove-unused-names", "remove-unused-brs", "remove-unused-names"],
    ) {
    Ok(mod) => mod
    Err(err) =>
      fail(
        "expected remove-unused-names/remove-unused-brs replay success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("Block("), msg=pretty)
}

///|
fn optimize_test_preserved_custom_secs() -> Array[@lib.CustomSec] {
  [@lib.CustomSec::new(@lib.Name::from_string("profile"), b"keep-me")]
}

///|
fn optimize_test_named_custom_module() -> @lib.Module {
  @lib.Module::new(
    custom_secs=optimize_test_preserved_custom_secs(),
    type_sec=Some(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    ),
    func_sec=Some(@lib.FuncSec::new([@lib.TypeIdx::new(0U)])),
    export_sec=Some(
      @lib.ExportSec::new([
        @lib.Export::new(
          @lib.Name::from_string("run"),
          @lib.ExternIdx::func(@lib.FuncIdx::new(0U)),
        ),
      ]),
    ),
    code_sec=Some(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
      ]),
    ),
  )
  .with_name_sec(
    @lib.NameSec::new(
      module_name=Some(@lib.Name::from_string("fixture")),
      func_names=Some(
        @lib.NameMap::new([
          @lib.NameAssoc::new(0U, @lib.Name::from_string("run")),
        ]),
      ),
    ),
  )
  .with_raw_name_sec_payload(b"raw-name")
}

///|
fn optimize_test_assert_preset_merges_exported_duplicate_functions(
  pass_name : String,
) -> Unit raise {
  let optimized = match
    run_hot_pipeline(
      pass_test_module_from_wat(
        (
          #|(module
          #|  (func $a (export "a") (result i32)
          #|    i32.const 7)
          #|  (func $b (export "b") (result i32)
          #|    i32.const 7))
        ),
      ),
      HotPipelineOptions::new(),
      [pass_name],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected \{pass_name} pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected \{pass_name} output to validate, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => @debug.assert_eq(funcs.length(), 1)
    None => fail("expected code section after \{pass_name}")
  }
  match optimized.export_sec {
    Some(@lib.ExportSec(exports)) => {
      @debug.assert_eq(exports.length(), 2)
      match (exports[0], exports[1]) {
        (
          @lib.Export(_, @lib.FuncExternIdx(@lib.FuncIdx(first))),
          @lib.Export(_, @lib.FuncExternIdx(@lib.FuncIdx(second))),
        ) => @debug.assert_eq(first, second)
        _ => fail("expected both exports to remain function exports")
      }
    }
    None => fail("expected exports after \{pass_name}")
  }
}

///|
test "optimize preset runs early duplicate-function-elimination on input duplicates" {
  try! optimize_test_assert_preset_merges_exported_duplicate_functions(
    "optimize",
  )
}

///|
test "shrink preset runs early duplicate-function-elimination on input duplicates" {
  try! optimize_test_assert_preset_merges_exported_duplicate_functions("shrink")
}
