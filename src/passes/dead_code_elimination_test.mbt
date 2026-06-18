///|
fn dead_code_elimination_test_count_occurrences(
  text : String,
  needle : String,
) -> Int {
  if needle == "" {
    return 0
  }
  let mut count = 0
  let mut start = 0
  while start <= text.length() - needle.length() {
    let mut found : Int? = None
    let mut i = start
    while i <= text.length() - needle.length() {
      if text.sub(start=i, end=i + needle.length()).to_owned() == needle {
        found = Some(i)
        break
      }
      i += 1
    }
    match found {
      Some(idx) => {
        count += 1
        start = idx + needle.length()
      }
      None => break
    }
  }
  count
}

///|
test "dead-code-elimination runs DCE-positive O4z raw pass" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 5 return i32.const 9 drop))",
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(
        optimize_level=4,
        shrink_level=1,
        trace=Some(fn(line) { trace.push(line) }),
      ),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected O4z dead-code-elimination success, got \{err}")
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[dead-code-elimination]:skip-raw reason=o4z-dead-code-elimination-noop",
      )
    }),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("return"), msg=pretty)
  assert_false(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "dead-code-elimination skips true straight-line no-candidate body" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func nop))",
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected no-candidate dead-code-elimination success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dead-code-elimination]:skip-raw reason=no-dce-candidates",
      )
    }),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("nop"), msg=pretty)
}

///|
test "dead-code-elimination collapses literal unreachable block before no-candidate raw skip" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func block unreachable end))",
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected literal unreachable block dead-code-elimination success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[dead-code-elimination]:skip-raw reason=no-dce-candidates",
      )
    }),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dead-code-elimination]:skip-raw reason=dce-explicit-dead-suffix",
      )
    }),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(block"), msg=pretty)
}

///|
test "dead-code-elimination trims root dead suffix before load-call-set hazard guard" {
  let trace : Array[String] = []
  let optimized = match
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
        #|    local.get $out
        #|    return
        #|    i32.const 9
        #|    drop))
        #|,
      ),
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected load-call-set dead-tail dead-code-elimination success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[dead-code-elimination]:skip-raw reason=load-call-set-dce-noop",
      )
    }),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dead-code-elimination]:skip-raw reason=load-call-set-dce-explicit-dead-suffix",
      )
    }),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return"), msg=pretty)
  assert_false(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "dead-code-elimination trims nested dead suffix before load-call-set hazard guard" {
  let trace : Array[String] = []
  let optimized = match
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
        #|    block
        #|      unreachable
        #|      i32.const 9
        #|      drop
        #|    end
        #|    local.get $out))
        #|,
      ),
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected load-call-set nested dead-tail dead-code-elimination success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[dead-code-elimination]:skip-raw reason=load-call-set-dce-noop",
      )
    }),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dead-code-elimination]:skip-raw reason=load-call-set-dce-explicit-dead-suffix",
      )
    }),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "dead-code-elimination skips load-call-set ownership hazards" {
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
        #|    local.get $out))
        #|,
      ),
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected load-call-set dead-code-elimination success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dead-code-elimination]:skip-raw reason=load-call-set-dce-noop",
      )
    }),
  )
}

///|
test "dead-code-elimination trims root dead suffix before loop outer-branch guard" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (param i32) (result i32)
        #|    block
        #|      loop
        #|        local.get 0
        #|        if
        #|          br 2
        #|        end
        #|        br 0
        #|      end
        #|    end
        #|    i32.const 1
        #|    return
        #|    i32.const 9
        #|    drop))
        #|,
      ),
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected loop outer-branch dead-tail dead-code-elimination success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[dead-code-elimination]:skip-raw reason=loop-outer-branch-dce-noop",
      )
    }),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dead-code-elimination]:skip-raw reason=loop-outer-branch-dce-explicit-dead-suffix",
      )
    }),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("return"), msg=pretty)
  assert_false(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "dead-code-elimination trims nested dead suffix before loop outer-branch guard" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (param i32) (result i32)
        #|    block
        #|      loop
        #|        local.get 0
        #|        if
        #|          br 2
        #|        end
        #|        br 0
        #|      end
        #|    end
        #|    block
        #|      unreachable
        #|      i32.const 9
        #|      drop
        #|    end
        #|    i32.const 1))
        #|,
      ),
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected loop outer-branch nested dead-tail dead-code-elimination success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[dead-code-elimination]:skip-raw reason=loop-outer-branch-dce-noop",
      )
    }),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dead-code-elimination]:skip-raw reason=loop-outer-branch-dce-explicit-dead-suffix",
      )
    }),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("I32(9)"), msg=pretty)
  assert_false(pretty.contains("I32(1)"), msg=pretty)
}

///|
test "dead-code-elimination skips loop bodies that branch to an outer block" {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (param i32) (result i32)
        #|    block
        #|      loop
        #|        local.get 0
        #|        if
        #|          br 2
        #|        end
        #|        br 0
        #|      end
        #|    end
        #|    i32.const 1))
        #|,
      ),
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected loop outer branch dead-code-elimination success, got \{err}",
      )
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[dead-code-elimination]:skip-raw reason=loop-outer-branch-dce-noop",
      )
    }),
  )
}

///|
test "dead-code-elimination trims non-control operands after unreachable child" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (block $out (drop (i32.add (block (result i32) nop unreachable) (br $out))))))",
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected non-control unreachable-child DCE success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_true(pretty.contains("nop"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
  assert_false(pretty.contains("br"), msg="\{trace}\n\{pretty}")
}

///|
test "dead-code-elimination trims global.set wrapper around unreachable value" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (global $g (mut f64) (f64.const 0)) (func i32.const 0 if (result f64) unreachable else unreachable end global.set $g))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected global.set unreachable-value DCE success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("global.set"), msg=pretty)
}

///|
test "dead-code-elimination preserves select values before unreachable condition" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $side (result i32) i32.const 7) (func call $side i32.const 456 unreachable select drop))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected select unreachable-condition DCE success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("I32(456)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("select"), msg=pretty)
}

///|
test "dead-code-elimination trims select tail after unreachable false value" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $side (result i32) i32.const 7) (func call $side unreachable i32.const 456 select drop))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected select unreachable-false-value DCE success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("I32(456)"), msg=pretty)
  assert_false(pretty.contains("select"), msg=pretty)
}

///|
test "dead-code-elimination preserves branch child when trimming unary wrapper" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (drop (i32.ctz (block $label (result i32) (br $label (i32.const 8)))))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected unary branch-child DCE success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("I32(8)"), msg=pretty)
  assert_false(pretty.contains("i32.ctz"), msg=pretty)
}

///|
test "dead-code-elimination drops if arms and suffix after unreachable condition" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) unreachable if (result i32) i32.const 1 else i32.const 2 end i32.const 3))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected unreachable-condition if DCE success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_false(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("I32(2)"), msg=pretty)
  assert_false(pretty.contains("I32(3)"), msg=pretty)
}

///|
test "dead-code-elimination preserves suffix after real legacy try with reachable catch" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func $foo)
        #|  (func
        #|    (try
        #|      (do
        #|        unreachable)
        #|      (catch_all))
        #|    call $foo))
        #|,
      ),
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected legacy try reachable-catch dead-code-elimination success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("try"), msg=pretty)
  assert_true(pretty.contains("catch_all"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
}

///|
test "dead-code-elimination repairs legacy pop nested in block after mutation" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let tag_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type, tag_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(1U))]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([@lib.LocalRun::new(1U, @lib.ValType::i32())]),
          @lib.Expr::new([
            @lib.Instruction::try_(
              @lib.BlockType::void_(),
              @lib.Expr::new([@lib.Instruction::nop()]),
              [
                @lib.LegacyCatch::new(
                  @lib.TagIdx::new(0U),
                  @lib.Expr::new([
                    @lib.Instruction::block(
                      @lib.BlockType::void_(),
                      @lib.Expr::new([
                        @lib.Instruction::pop(@lib.ValType::i32()),
                        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
                      ]),
                    ),
                  ]),
                ),
              ],
            ),
            @lib.Instruction::i32_const(@lib.I32(7)),
          ]),
        ),
      ]),
    )
  let func = match
    @ir.hot_lift_func_with_context_result(
      mod_,
      @lib.FuncIdx::new(0U),
      @ir.hot_module_context_from_module(mod_),
    ) {
    Ok(func) => func
    Err(err) => fail("expected legacy pop fixture to lift, got \{err}")
  }
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected legacy pop repair DCE success, got \{err}")
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = mod_
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "dead-code-elimination repairs legacy pop nested below catch root block" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let tag_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type, tag_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(1U))]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([
            @lib.Instruction::try_(
              @lib.BlockType::void_(),
              @lib.Expr::new([@lib.Instruction::nop()]),
              [
                @lib.LegacyCatch::new(
                  @lib.TagIdx::new(0U),
                  @lib.Expr::new([
                    @lib.Instruction::block(
                      @lib.BlockType::val_type(@lib.ValType::i32()),
                      @lib.Expr::new([
                        @lib.Instruction::pop(@lib.ValType::i32()),
                      ]),
                    ),
                    @lib.Instruction::drop(),
                  ]),
                ),
              ],
            ),
            @lib.Instruction::i32_const(@lib.I32(7)),
          ]),
        ),
      ]),
    )
  let func = match
    @ir.hot_lift_func_with_context_result(
      mod_,
      @lib.FuncIdx::new(0U),
      @ir.hot_module_context_from_module(mod_),
    ) {
    Ok(func) => func
    Err(err) => fail("expected nested legacy pop fixture to lift, got \{err}")
  }
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected nested legacy pop repair DCE success, got \{err}")
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = mod_
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "dead-code-elimination repairs legacy pop in dead call argument before unreachable" {
  let func = @ir.HotFunc::new()
  let call = @ir.hot_build_call(func, 1, [], [
    @ir.hot_build_legacy_pop(func, @lib.ValType::i32()),
    @ir.hot_build_unreachable(func),
  ])
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_nop(func)],
    catch_body=Some([call, @ir.hot_build_nop(func)]),
  )
  @ir.hot_legacy_try_catches_set(func, try_id, [
    @ir.HotCatchArm::legacy_catch(@lib.TagIdx::new(0U), 2),
  ])
  @ir.hot_root_append(func, try_id)
  @ir.hot_root_append(func, @ir.hot_build_const_i32(func, @lib.I32(7)))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected call-pop-unreachable legacy DCE success, got \{err}")
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], []),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(1U)]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(2U))]))
    .with_code_sec(
      @lib.CodeSec::new([
        lowered,
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::nop()]),
        ),
      ]),
    )
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "dead-code-elimination repairs legacy pop in dead call argument before branch" {
  let func = @ir.HotFunc::new()
  let block = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let branch = @ir.hot_build_br(func, @ir.hot_control_node_label(func, block))
  let call = @ir.hot_build_call(func, 1, [], [
    @ir.hot_build_legacy_pop(func, @lib.ValType::i32()),
    branch,
  ])
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [@ir.hot_build_nop(func)],
    catch_body=Some([call, @ir.hot_build_nop(func)]),
  )
  @ir.hot_legacy_try_catches_set(func, try_id, [
    @ir.HotCatchArm::legacy_catch(@lib.TagIdx::new(0U), 2),
  ])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, block), [
    try_id,
  ])
  @ir.hot_root_append(func, block)
  @ir.hot_root_append(func, @ir.hot_build_const_i32(func, @lib.I32(7)))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected call-pop-branch legacy DCE success, got \{err}")
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], []),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([@lib.TypeIdx::new(0U), @lib.TypeIdx::new(1U)]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(2U))]))
    .with_code_sec(
      @lib.CodeSec::new([
        lowered,
        @lib.Func::new(
          @lib.Locals::new([]),
          @lib.Expr::new([@lib.Instruction::nop()]),
        ),
      ]),
    )
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
}

///|
test "dead-code-elimination repairs legacy pop nested by drop ref-eq unreachable child" {
  let eqref = @lib.ValType::eqref_null()
  let func = @ir.HotFunc::new()
  let struct_new = @ir.hot_build_heap(
    func,
    [eqref],
    @lib.Instruction::struct_new(@lib.TypeIdx::new(0U)),
    [@ir.hot_build_legacy_pop(func, eqref)],
  )
  let ref_eq = @ir.hot_build_heap(
    func,
    [@lib.ValType::i32()],
    @lib.Instruction::ref_eq(),
    [
      struct_new,
      @ir.hot_build_block(func, @lib.BlockType::val_type(eqref), [
        @ir.hot_build_unreachable(func),
      ]),
    ],
  )
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [@ir.hot_build_const_i32(func, @lib.I32(0))],
    catch_body=Some([
      @ir.hot_build_drop(func, ref_eq),
      @ir.hot_build_const_i32(func, @lib.I32(0)),
    ]),
  )
  @ir.hot_legacy_try_catches_set(func, try_id, [
    @ir.HotCatchArm::legacy_catch(@lib.TagIdx::new(0U), 2),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, try_id))
  @ir.hot_root_append(func, @ir.hot_build_const_i32(func, @lib.I32(9)))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected pop-within-block legacy DCE success, got \{err}")
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::struct_([
              @lib.FieldType::new(
                @lib.StorageType::val_type(eqref),
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
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([eqref], [])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(@lib.TypeIdx::new(2U))]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("I32(9)"), msg=pretty)
  assert_false(pretty.contains("ref.eq"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "dead-code-elimination treats lowered legacy try with all arms unreachable as nonfallthrough" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func
        #|    (try
        #|      (do
        #|        unreachable)
        #|      (catch_all
        #|        unreachable))
        #|    i32.const 9
        #|    drop))
        #|,
      ),
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected legacy try all-unreachable dead-code-elimination success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "dead-code-elimination removes call-pop-catch dead call text" {
  let source =
    #|(module
    #|  (tag $e-i32 (param i32))
    #|  (func
    #|    (block $label
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32
    #|          (call $helper
    #|            (pop i32)
    #|            (br $label))
    #|          nop))))
    #|  (func $helper (param i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected call-pop-catch DCE pipeline success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs call-pop-catch dead call before return text" {
  let source =
    #|(module
    #|  (tag $e-i32 (param i32))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (pop i32)
    #|          (return))
    #|        nop)))
    #|  (func $helper (param i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected call-pop-catch return DCE pipeline success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("return"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination documents unsupported stack-switching boundary" {
  let source =
    #|(module
    #|  (type $function (func))
    #|  (type $cont (cont $function))
    #|  (tag $tag (type $function))
    #|  (func $resume (param $c (ref $cont))
    #|    (block $exit
    #|      (drop
    #|        (block $handle_effect (result (ref $cont))
    #|          (resume $cont (on $tag $handle_effect)
    #|            (local.get $c))
    #|          (br $exit)))))
    #|  (func $resume_throw (param $c (ref $cont))
    #|    (block $exit
    #|      (drop
    #|        (block $handle_effect (result (ref $cont))
    #|          (resume_throw $cont $tag (on $tag $handle_effect)
    #|            (local.get $c))
    #|          (br $exit))))))
    #|)
    #|
  let parsed = match
    @wast.wast_to_module(source, filename="dce-stack-switching-boundary.wat") {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected Binaryen DCE stack-switching fixture to parse as WAST placeholder: \{err}",
      )
  }
  let printed = match @wast.module_to_wast(parsed) {
    Ok(text) => text
    Err(err) =>
      fail(
        "expected Binaryen DCE stack-switching fixture to print as WAST placeholder: \{err}",
      )
  }
  assert_true(printed.contains("(type $cont (cont $function))"), msg=printed)
  assert_true(printed.contains("(tag $tag (type $function))"), msg=printed)
  assert_true(
    printed.contains("resume $cont (on $tag $handle_effect)"),
    msg=printed,
  )
  assert_true(
    printed.contains("resume_throw $cont $tag (on $tag $handle_effect)"),
    msg=printed,
  )

  match
    @wast.wast_to_binary_module(
      source,
      filename="dce-stack-switching-boundary.wat",
    ) {
    Ok(_) =>
      fail(
        "stack-switching handler-label DCE fixtures must stay unsupported until @lib/@wast represent cont/resume/on labels",
      )
    Err(err) => {
      assert_true(err.contains("stack-switching"), msg=err)
      assert_true(err.contains("cont"), msg=err)
      assert_true(err.contains("resume"), msg=err)
      assert_true(err.contains("resume_throw"), msg=err)
      assert_true(err.contains("on"), msg=err)
      assert_true(err.contains("dce-stack-switching-boundary.wat"), msg=err)
    }
  }
}

///|
test "dead-code-elimination treats try_table unreachable body as nonfallthrough" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func
        #|    (try_table (catch_all 0)
        #|      unreachable)
        #|    i32.const 9
        #|    drop))
        #|,
      ),
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected try_table dead-code-elimination success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("try_table"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "dead-code-elimination collapses result try_table with unreachable body" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func
        #|    (block $h
        #|      (try_table (result i32) (catch_all $h)
        #|        unreachable)
        #|      drop
        #|      i32.const 9
        #|      drop)))
        #|,
      ),
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected result try_table dead-code-elimination success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("try_table"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("I32(9)"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
}

///|
test "dead-code-elimination preserves pure drop roots for oracle parity" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 1 drop i32.const 7))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dead-code-elimination success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(pretty.contains("I32(7)"))
}

///|
test "cleanup prefix preserves trailing unreachable after terminal void if in result function" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) local.get 0 if unreachable else i32.const 0 return end unreachable))",
      ["dead-code-elimination", "remove-unused-names", "remove-unused-brs"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected cleanup prefix terminal void-if success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(
    dead_code_elimination_test_count_occurrences(pretty, "unreachable") >= 2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination removes unreachable roots after return" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 5 return i32.const 9 drop))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dead-code-elimination success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("return"))
  assert_false(pretty.contains("I32(9)"))
}

///|
test "dead-code-elimination avoids wrapping parent-exit payloads in extra result blocks" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (result i32) (local i32) (block $outer (result i32) (block $exit (block $work (if (i32.eq (local.get 0) (i32.const 1)) (then (local.set 2 (local.get 1)) (br $work)) (else (local.set 2 (i32.const 9)) (br $exit))) unreachable) (br $outer (local.get 2))) (i32.const 0))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected dead-code-elimination parent-exit payload success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_true(pretty.contains("(block (Void)"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
}

///|
test "dead-code-elimination voids dead if results and drops pure arm values" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) local.get 0 if (result i32) i32.const 1 else i32.const 2 end drop i32.const 7))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dead-code-elimination success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(if (Void)"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("I32(2)"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "dead-code-elimination preserves imported calls with dead results" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (type (func (result i32))) (import \"env\" \"ping\" (func (type 0))) (func (result i32) call 0 drop i32.const 7))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dead-code-elimination success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "dead-code-elimination preserves global.get roots with dead results" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (global i32 (i32.const 0)) (func (result i32) global.get 0 drop i32.const 7))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected dead-code-elimination to preserve global.get roots, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "dead-code-elimination preserves dead type-index block wrappers" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (type (func (result i32))) (func (result i32) block (type 0) i32.const 1 end drop i32.const 7))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected dead-code-elimination type-index block success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(block (Type 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "dead-code-elimination keeps value roots that feed later roots in void regions" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 if block (result i32) i32.const 1 end local.set 1 end i32.const 7))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected dead-code-elimination to preserve live void-region values, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(block I32"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "dead-code-elimination keeps typed branch wrappers with label-targeted payload branches" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) block (result i32) block local.get 0 if i32.const 1 local.set 1 br 1 end i32.const 0 br 1 end end drop local.get 1))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected dead-code-elimination to preserve typed branch wrappers, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(block I32"), msg=pretty)
  assert_true(pretty.contains("I32(0)"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
}

///|
test "dead-code-elimination removes branch-skipping result block wrappers under drop" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) block block (result i32) local.get 0 if br 2 else br 2 end i32.const 1000 end drop end i32.const 0))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected dead-code-elimination to remove branch-skipping result block wrappers, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(block I32"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("I32(1000)"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("I32(0)"), msg=pretty)
}

///|
test "dead-code-elimination removes typed branch-payload forwarders that only feed later block results" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32) (block $out (result i32) (block $exit (br $out (block $mid (result i32) (block $cont (br $mid (if (result i32) (local.get 0) (then (i32.const 1) (local.set 1) (br $cont)) (else (br $exit))))) (local.get 1)))) (i32.const 9))))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination payload-forwarder success, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "dead-code-elimination removes typed branch-payload forwarders nested under local.set" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (param i32 i32) (result i32) (local i32) (local i32) (local.set 2 (block $out (result i32) (block $exit (br $out (block $mid (result i32) (block $cont (br $mid (if (result i32) (local.get 0) (then (i32.const 1) (local.set 3) (br $cont)) (else (br $exit))))) (local.get 3)))) (local.get 1))) (local.get 2)))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination nested payload-forwarder success, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "dead-code-elimination removes typed branch-payload forwarders with prefix work nested under local.set" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (param i32 i32) (result i32) (local i32) (local i32) (local.set 2 (block $out (result i32) (block $exit (br $out (block $mid (result i32) (block $cont (local.set 3 (local.get 1)) (br $mid (if (result i32) (local.get 0) (then (i32.const 1) (local.set 2) (br $cont)) (else (i32.const 2) (local.set 3) (br $exit))))) (local.get 3)))) (i32.const 9))) (local.get 2)))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination prefixed nested payload-forwarder success, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "dead-code-elimination removes stacked typed branch-payload forwarders nested under local.set" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (param i32 i32) (result i32) (local i32) (local i32) (local.set 2 (block $out (result i32) (block $exit (br $out (block $mid (result i32) (block $cont (local.set 3 (local.get 1)) (if (result i32) (local.get 0) (then (i32.const 1) (local.set 2) (br $cont)) (else (i32.const 2) (local.set 3) (br $exit))) (br $mid)) (local.get 3)))) (i32.const 9))) (local.get 2)))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination stacked nested payload-forwarder success, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "dead-code-elimination removes direct void-if payload forwarders with trailing values" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (param i32 i32) (result i32) (local i32) (local.set 2 (block $out (result i32) (block $exit (br $out (block $mid (result i32) (block $cont (local.set 2 (local.get 0)) (if (local.get 1) (then (local.set 2 (i32.const 7)) (br $exit)) (else (local.set 2 (i32.const 9)))) unreachable) (local.get 2)))) (i32.const 5))) (local.get 2)))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination direct void-if payload-forwarder success, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(br $mid"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "dead-code-elimination removes dead unreachable tails from split payload wrappers" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (param i32) (result i32) (local i32 i32) (block $block11 (result i32) (block $block9 (br $block11 (block $block10 (result i32) (block $block8 (local.set 1 (i32.const 1)) (if (local.get 0) (then (local.set 1 (i32.const 7)) (br $block8)) (else (local.set 1 (i32.const 9)) (br $block9))) unreachable) (local.get 1)))) (i32.store align=1 (i32.const 0) (local.get 1)) (i32.store align=1 (i32.const 4) (local.get 1)) (return (local.get 1)))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected dead-code-elimination split payload wrapper success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "unreachable"),
    1,
    msg=pretty,
  )
  assert_false(pretty.contains("(block $block10 (result i32)"), msg=pretty)
  assert_false(pretty.contains("(br $block10"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "dead-code-elimination removes dead drop wrappers around non-fallthrough branches" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (block $out (result i32) (drop (br $out (local.get 0))))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected dead-code-elimination to remove dead drop around branch payload, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(br "), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
}

///|
test "dead-code-elimination voidifies dropped nonfallthrough result blocks with inner branch labels" {
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let inner = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let inner_label = @ir.hot_control_node_label(func, inner)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, inner), [
    @ir.hot_build_br(func, inner_label),
  ])
  let wrapped = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [
      inner,
      @ir.hot_build_return(func, [@ir.hot_build_const_i32(func, @lib.I32(1))]),
    ],
  )
  @ir.hot_root_append(func, @ir.hot_build_drop(func, wrapped))
  @ir.hot_root_append(func, @ir.hot_build_const_i32(func, @lib.I32(7)))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination to voidify dropped nonfallthrough blocks, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(block (Void)"), msg=pretty)
  assert_false(pretty.contains("(drop (block I32"), msg=pretty)
  assert_true(pretty.contains("return"), msg=pretty)
}

///|
test "dead-code-elimination removes split drop roots after nonfallthrough result blocks" {
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let inner = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let inner_label = @ir.hot_control_node_label(func, inner)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, inner), [
    @ir.hot_build_br(func, inner_label),
  ])
  let wrapped = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [
      inner,
      @ir.hot_build_return(func, [@ir.hot_build_const_i32(func, @lib.I32(1))]),
    ],
  )
  let dropped = @ir.hot_build_drop(func, wrapped)
  @ir.hot_root_append(func, wrapped)
  @ir.hot_root_append(func, dropped)
  @ir.hot_root_append(func, @ir.hot_build_const_i32(func, @lib.I32(7)))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination split-drop nonfallthrough success, got \{err}",
      )
  }

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  let root0 = @ir.hot_root_get(func, 0)
  @debug.assert_eq(root0, wrapped)
  @debug.assert_eq(@ir.hot_node_result_arity(func, root0), 0)
  let root1 = @ir.hot_root_get(func, 1)
  match @ir.hot_node_get(func, root1).op {
    @ir.HotOp::Unreachable => ()
    other => fail("expected explicit unreachable tail, got \{other}")
  }
}

///|
test "dead-code-elimination voidifies nonfinal nonfallthrough value blocks in lifted void regions" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 1 if block (result i32) block br 0 end i32.const 5 local.set 0 i32.const 1 return end local.get 0 drop end i32.const 7))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected dead-code-elimination nonfinal nonfallthrough value-block success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(drop (block I32"), msg=pretty)
  assert_true(pretty.contains("(block (Void)"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "dead-code-elimination voidifies dropped nonfallthrough value blocks with incoming pure payload branches" {
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let wrapped = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let wrapped_label = @ir.hot_control_node_label(func, wrapped)
  let inner = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    @ir.hot_build_br(func, wrapped_label, values=[
      @ir.hot_build_const_i32(func, @lib.I32(0)),
    ]),
  ])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, wrapped), [
    inner,
    @ir.hot_build_return(func, [@ir.hot_build_const_i32(func, @lib.I32(1))]),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, wrapped))
  @ir.hot_root_append(func, @ir.hot_build_const_i32(func, @lib.I32(7)))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination dropped pure-payload branch wrapper success, got \{err}",
      )
  }

  let root0 = @ir.hot_root_get(func, 0)
  @debug.assert_eq(root0, wrapped)
  @debug.assert_eq(@ir.hot_node_result_arity(func, root0), 0)
  let root1 = @ir.hot_root_get(func, 1)
  match @ir.hot_node_get(func, root1).op {
    @ir.HotOp::Const => ()
    other =>
      fail(
        "expected drop wrapper removal to expose trailing const, got \{other}",
      )
  }
}

///|
test "dead-code-elimination preserves consecutive pure drop roots" {
  let func = pass_test_lift_first_func(
    "(module (func i32.const 1 drop i32.const 2 drop i32.const 3 drop))",
  )
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected consecutive pure-drop dead-code-elimination success, got \{err}",
      )
  }

  @debug.assert_eq(@ir.hot_root_count(func), 3)
  for idx = 0; idx < 3; idx = idx + 1 {
    let root = @ir.hot_root_get(func, idx)
    match @ir.hot_node_get(func, root).op {
      @ir.HotOp::Drop => ()
      other => fail("expected drop root at \{idx}, got \{other}")
    }
  }
}

///|
test "dead-code-elimination folds nonfallthrough prefix blocks into branch payloads" {
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )

  let payload_value = @ir.hot_build_const_i32(func, @lib.I32(7))
  let prefix = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let prefix_label = @ir.hot_control_node_label(func, prefix)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, prefix), [
    @ir.hot_build_br(func, prefix_label),
    @ir.hot_build_unreachable(func),
  ])

  let out = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let out_label = @ir.hot_control_node_label(func, out)
  let branch = @ir.hot_build_br(func, out_label, values=[payload_value])
  let mid = @ir.hot_build_block(func, @lib.BlockType::void_(), [prefix, branch])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, out), [
    mid,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
  ])
  @ir.hot_root_append(func, out)

  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected prefix-payload fixture core verification, got \{err}")
  }
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected prefix-payload fixture control verification, got \{err}")
  }
  @debug.assert_eq(
    @ir.hot_region_root_count(func, @ir.hot_region_body_ref(func, mid)),
    2,
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination prefix-payload fold success, got \{err}",
      )
  }

  let mid_region = @ir.hot_region_body_ref(func, mid)
  @debug.assert_eq(@ir.hot_region_root_count(func, mid_region), 1)
  let folded_branch = @ir.hot_region_get(func, mid_region, 0)
  match @ir.hot_node_get(func, folded_branch).op {
    @ir.HotOp::Br => ()
    other => fail("expected folded root branch, got \{other}")
  }
  let folded_payload = @ir.hot_child_get(func, folded_branch, 0)
  match @ir.hot_node_get(func, folded_payload).op {
    @ir.HotOp::Block => ()
    other => fail("expected folded branch payload block, got \{other}")
  }
  let folded_region = @ir.hot_region_body_ref(func, folded_payload)
  @debug.assert_eq(@ir.hot_region_root_count(func, folded_region), 2)
  @debug.assert_eq(@ir.hot_region_get(func, folded_region, 0), prefix)
  @debug.assert_eq(@ir.hot_region_get(func, folded_region, 1), payload_value)
}

///|
test "dead-code-elimination retargets stacked payload blocks to the inner result block" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32) (block $outer (result i32) (block $exit (br $outer (block $inner (result i32) (block $cont (br $inner (if (result i32) (local.get 0) (then (i32.const 1) (local.set 1) (br $cont)) (else (br $exit)))))))) (i32.const 9))))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination stacked payload retarget success, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(block (Void)"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "dead-code-elimination preserves explicit unreachable in branchy carried result blocks" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32 i32) (block $block2 (result i32) (block $block1 (br $block2 (block (result i32) (block $block (if (local.get 0) (then (local.set 1 (i32.const 7)) (br $block)) (else (local.set 2 (i32.const 9)) (br $block1))) unreachable) (local.get 1)))))))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination branchy carried-result wrapper success, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "dead-code-elimination preserves outer wrapper payload forwarders in local.set values when oracle keeps them" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (param i32 i32 i32) (result i32) (local i32 i32) (local.set 3 (block $outer (result i32) (block $mid (br $outer (block $inner (result i32) (block $cont (local.set 4 (local.get 0)) (drop (local.get 1)) (drop (local.get 2)) (br $inner (if (result i32) (local.get 0) (then (local.set 4 (local.get 1)) (br $cont)) (else (local.set 3 (local.get 2)) (br $mid))))) (local.get 4)))) (local.get 3))) (local.get 3)))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination outer-wrapper payload preservation success, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
              [@lib.ValType::i32()],
            ),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_true(pretty.contains("(local.set (Local 4))"), msg=pretty)
  assert_true(pretty.contains("(local.set (Local 3))"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "dead-code-elimination rewrites split local.set wrapper forwarders" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (param i32 i32) (result i32) (local i32) (local.set 2 (block $outer (result i32) (block $exit (block $mid (result i32) (block $cont (local.get 0) (if (result i32) (local.get 1) (then (i32.const 1) (br $cont)) (else (i32.const 2))) (br $mid)) (local.get 0)) (br $outer (block $inner (result i32) (block $carry (br $inner (if (result i32) (local.get 1) (then (local.get 0) (br $carry)) (else (local.get 0)))))))) (local.get 2))) (local.get 2)))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination split local.set wrapper rewrite success, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "dead-code-elimination rewrites split local.set wrapper direct payload tails with trailing values" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (param i32 i32) (result i32) (local i32) (local i32) (local.set 2 (block $outer (result i32) (block $exit (br $outer (block $mid (result i32) (block $cont (local.set 3 (local.get 1)) (br $mid (if (result i32) (local.get 0) (then (local.set 3 (i32.const 7)) (br $cont)) (else (local.set 3 (i32.const 9)) (br $exit))))) (local.get 3)))) (i32.const 1))) (local.get 2)))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination split local.set direct-tail rewrite success, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
  assert_false(pretty.contains("(br $mid"), msg=pretty)
}

///|
test "dead-code-elimination retargets nested split local.set wrapper payload blocks" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (param i32 i32) (result i32) (local i32) (local i32) (local.set 2 (block $block11 (result i32) (block $block9 (br $block11 (block $block10 (result i32) (block $block8 (local.set 3 (local.get 0)) (br $block10 (if (result i32) (local.get 1) (then (local.set 3 (i32.const 7)) (br $block8)) (else (local.set 3 (i32.const 9)) (br $block9))))) (local.get 3)))) (i32.const 1))) (local.get 2)))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination nested split local.set payload retarget success, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(block $block11 (result i32)"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "dead-code-elimination retargets split local.set wrappers with trailing outer roots" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (param i32 i32) (result i32) (local i32) (local i32) (local.set 2 (block $block11 (result i32) (block $block9 (br $block11 (block $block10 (result i32) (block $block8 (local.set 3 (local.get 0)) (br $block10 (if (result i32) (local.get 1) (then (local.set 3 (i32.const 7)) (br $block8)) (else (local.set 3 (i32.const 9)) (br $block9))))) (local.get 3)))) (drop (local.get 0)) (local.get 3))) (local.get 2)))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination split local.set trailing-root retarget success, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(block $block11 (result i32)"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "dead-code-elimination retargets split local.set wrappers with void-if forwarders" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32 i32) (local.set 1 (block $outer (result i32) (block $exit (br $outer (block $mid (result i32) (block $cont (if (local.get 0) (then (local.set 2 (i32.const 7)) (br $cont)) (else (local.set 2 (i32.const 9)) (br $exit))) unreachable) (local.get 2)))) (local.get 1))) (local.get 1)))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination split local.set void-if forwarder success, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(block $outer (result i32)"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "dead-code-elimination retargets split local.set wrappers with void-if forwarders and trailing outer roots" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32 i32) (local.set 1 (block $outer (result i32) (block $exit (br $outer (block $mid (result i32) (block $cont (if (local.get 0) (then (local.set 2 (i32.const 7)) (br $cont)) (else (local.set 2 (i32.const 9)) (br $exit))) unreachable) (local.get 2)))) (drop (local.get 0)) (local.get 1))) (local.get 1)))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination split local.set void-if trailing-root success, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(block $outer (result i32)"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "dead-code-elimination retargets prefix-heavy split local.set void-if forwarders" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (param i32 i32 i32) (result i32) (local i32 i32) (local.set 3 (block $block11 (result i32) (block $block9 (br $block11 (block $block10 (result i32) (block $block8 (local.set 4 (local.get 0)) (drop (local.get 1)) (drop (local.get 2)) (if (local.get 2) (then (local.set 4 (i32.const 7)) (br $block8)) (else (local.set 4 (i32.const 9)) (br $block9))) unreachable) (local.get 4)))) (local.get 3))) (local.get 3)))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination prefix-heavy split local.set void-if rewrite success, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
              [@lib.ValType::i32()],
            ),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(block $block11 (result i32)"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|
test "dead-code-elimination retargets prefix-heavy nested split local.set payload blocks" {
  let mod_ = pass_test_module_from_wat(
    "(module (func (param i32 i32 i32) (result i32) (local i32) (local i32) (local.set 3 (block $block11 (result i32) (block $block9 (br $block11 (block $block10 (result i32) (block $block8 (local.set 4 (local.get 0)) (drop (local.get 1)) (drop (local.get 2)) (br $block10 (if (result i32) (local.get 2) (then (local.set 4 (i32.const 7)) (br $block8)) (else (local.set 4 (i32.const 9)) (br $block9))))) (local.get 4)))) (local.get 3))) (local.get 3)))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination prefix-heavy nested split local.set payload retarget success, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
              [@lib.ValType::i32()],
            ),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(block $block11 (result i32)"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|

///|
test "dead-code-elimination retargets split wrappers with store-store-return tails" {
  let mod_ = pass_test_module_from_wat(
    "(module (memory 1) (func (param i32) (result i32) (local i32 i32) (local.set 1 (block $block11 (result i32) (block $block9 (br $block11 (block $block10 (result i32) (block $block8 (local.set 2 (i32.const 1)) (br $block10 (if (result i32) (local.get 0) (then (local.set 2 (i32.const 7)) (br $block8)) (else (local.set 2 (i32.const 9)) (br $block9))))) (local.get 2)))) (i32.store align=1 (i32.const 0) (local.get 2)) (i32.store align=1 (i32.const 4) (local.get 2)) (return (local.get 2)))) (i32.const 0)))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination store/store/return split wrapper success, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1, None))]),
    )
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("(block $block11 (result i32)"), msg=pretty)
  assert_false(pretty.contains("(if I32"), msg=pretty)
}

///|

///|
test "dead-code-elimination keeps typed if wrappers with hidden region-label payload branches" {
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    else_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let then_region = @ir.hot_region_then_ref(func, if_id)
  let then_label = @ir.hot_control_node_label(func, then_region.holder)
  @ir.hot_region_replace_body(func, then_region, [
    @ir.hot_build_br(func, then_label, values=[
      @ir.hot_build_const_i32(func, @lib.I32(1)),
    ]),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, if_id))
  @ir.hot_root_append(func, @ir.hot_build_const_i32(func, @lib.I32(7)))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) => fail("expected test fixture core verification, got \{err}")
  }
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) => fail("expected test fixture control verification, got \{err}")
  }
  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination hidden-region-branch success, got \{err}",
      )
  }

  @debug.assert_eq(@ir.hot_node_result_arity(func, if_id), 1)
  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) => fail("expected typed if wrapper to remain valid, got \{err}")
  }
}

///|
test "dead-code-elimination keeps typed if wrappers with hidden br_table payload branches" {
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    else_body=Some([@ir.hot_build_const_i32(func, @lib.I32(2))]),
  )
  let then_region = @ir.hot_region_then_ref(func, if_id)
  let then_label = @ir.hot_control_node_label(func, then_region.holder)
  @ir.hot_region_replace_body(func, then_region, [
    @ir.hot_build_br_table(
      func,
      [then_label],
      then_label,
      @ir.hot_build_const_i32(func, @lib.I32(0)),
      values=[@ir.hot_build_const_i32(func, @lib.I32(1))],
    ),
  ])
  @ir.hot_root_append(func, @ir.hot_build_drop(func, if_id))
  @ir.hot_root_append(func, @ir.hot_build_const_i32(func, @lib.I32(7)))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) => fail("expected br_table fixture core verification, got \{err}")
  }
  match @ir.hot_verify_control(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected br_table fixture control verification, got \{err}")
  }
  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected dead-code-elimination hidden br_table success, got \{err}")
  }

  @debug.assert_eq(@ir.hot_node_result_arity(func, if_id), 1)
  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected typed if br_table wrapper to remain valid, got \{err}")
  }
}

///|
test "dead-code-elimination removes nested unreachable roots after return" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func block return i32.const 9 drop end))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dead-code-elimination success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("return"), msg=pretty)
  assert_false(pretty.contains("I32(9)"), msg=pretty)
}

///|
test "dead-code-elimination keeps detached label owners live after unreachable-tail pruning" {
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let ret = @ir.hot_build_return(func, [
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  ])
  let dead_block = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  ])
  @ir.hot_root_append(func, ret)
  @ir.hot_root_append(func, dead_block)
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination label-owner pruning success, got \{err}",
      )
  }

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  @debug.assert_eq(@ir.hot_root_get(func, 0), ret)
  assert_true(@ir.hot_node_is_live(func, dead_block))
  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected detached label owner to remain core-valid, got \{err}")
  }
}

///|
test "dead-code-elimination deletes detached shared subtrees after unreachable tails" {
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let shared = @ir.hot_build_const_i32(func, @lib.I32(1))
  let drop0 = @ir.hot_build_drop(func, shared)
  let drop1 = @ir.hot_build_drop(func, shared)
  let ret = @ir.hot_build_return(func, [
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  ])
  @ir.hot_root_append(func, ret)
  @ir.hot_root_append(func, drop0)
  @ir.hot_root_append(func, drop1)
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected dead-code-elimination shared-subtree success, got \{err}")
  }

  @debug.assert_eq(@ir.hot_root_count(func), 1)
  @debug.assert_eq(@ir.hot_root_get(func, 0), ret)
  assert_false(@ir.hot_node_is_live(func, shared))
  assert_false(@ir.hot_node_is_live(func, drop0))
  assert_false(@ir.hot_node_is_live(func, drop1))
}

///|
test "dead-code-elimination materializes unreachable tails after voidifying typed loop-body wrappers" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (import \"env\" \"array_length\" (func $moonbit.array_length (param i32) (result i32))) (memory 1) (func $moonbit.string_equal (param $stra i32) (param $strb i32) (result i32) (local $counter i32) local.get $stra call $moonbit.array_length local.get $strb call $moonbit.array_length i32.eq if (result i32) loop (result i32) local.get $counter local.get $stra call $moonbit.array_length i32.lt_s if (result i32) local.get $stra local.get $counter i32.const 1 i32.shl i32.add i32.load16_u offset=8 align=1 local.get $strb local.get $counter i32.const 1 i32.shl i32.add i32.load16_u offset=8 align=1 i32.eq if (result i32) local.get $counter i32.const 1 i32.add local.set $counter br 2 else i32.const 0 return end else i32.const 1 return end end else i32.const 0 return end))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected dead-code-elimination to voidify dead loop-body typing wrappers, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("(if (Void)"), msg=pretty)
  assert_true(pretty.contains("(loop (Void)"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(
    dead_code_elimination_test_count_occurrences(pretty, "unreachable") >= 1,
    msg=pretty,
  )
}

///|
test "dead-code-elimination leaves explicit unreachable root after final voidified control" {
  let mod_ = pass_test_module_from_wat(
    "(module (import \"env\" \"array_length\" (func $moonbit.array_length (param i32) (result i32))) (memory 1) (func $moonbit.string_equal (param $stra i32) (param $strb i32) (result i32) (local $counter i32) local.get $stra call $moonbit.array_length local.get $strb call $moonbit.array_length i32.eq if (result i32) loop (result i32) local.get $counter local.get $stra call $moonbit.array_length i32.lt_s if (result i32) local.get $stra local.get $counter i32.const 1 i32.shl i32.add i32.load16_u offset=8 align=1 local.get $strb local.get $counter i32.const 1 i32.shl i32.add i32.load16_u offset=8 align=1 i32.eq if (result i32) local.get $counter i32.const 1 i32.add local.set $counter br 2 else i32.const 0 return end else i32.const 1 return end end else i32.const 0 return end))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(1U))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination final control tail success, got \{err}",
      )
  }

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  let tail_id = @ir.hot_root_get(func, 1)
  match @ir.hot_node_get(func, tail_id).op {
    @ir.HotOp::Unreachable => ()
    other => fail("expected explicit unreachable tail root, got \{other}")
  }
}

///|
test "dead-code-elimination lowering avoids nested unreachable tails for typed loop-body wrappers" {
  let mod_ = pass_test_module_from_wat(
    "(module (import \"env\" \"array_length\" (func $moonbit.array_length (param i32) (result i32))) (memory 1) (func $moonbit.string_equal (param $stra i32) (param $strb i32) (result i32) (local $counter i32) local.get $stra call $moonbit.array_length local.get $strb call $moonbit.array_length i32.eq if (result i32) loop (result i32) local.get $counter local.get $stra call $moonbit.array_length i32.lt_s if (result i32) local.get $stra local.get $counter i32.const 1 i32.shl i32.add i32.load16_u offset=8 align=1 local.get $strb local.get $counter i32.const 1 i32.shl i32.add i32.load16_u offset=8 align=1 i32.eq if (result i32) local.get $counter i32.const 1 i32.add local.set $counter br 2 else i32.const 0 return end else i32.const 1 return end end else i32.const 0 return end))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(1U))
  let ctx = HotPassContext::new(
    dead_code_elimination_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected dead-code-elimination lowered loop-body wrapper success, got \{err}",
      )
  }

  let pretty = mod_
    .with_code_sec(@lib.CodeSec::new([@ir.hot_lower_func(func)]))
    .pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("(if (Void)"), msg=pretty)
  assert_true(pretty.contains("(loop (Void)"), msg=pretty)
  assert_true(
    dead_code_elimination_test_count_occurrences(pretty, "unreachable") >= 1,
    msg=pretty,
  )
}
