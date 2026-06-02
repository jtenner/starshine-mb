///|
fn ssa_test_first_defined_func(
  mod_ : @lib.Module,
) -> (@lib.Locals, Array[@lib.Instruction]) raise {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs.get(0) {
        Some(@lib.Func(locals, @lib.Expr(instrs))) => (locals, instrs)
        None => fail("expected first defined function")
      }
    None => fail("expected code section")
  }
}

///|
fn ssa_test_run_hot_path_only(text : String) -> Result[@lib.Module, String] {
  let mod_ = pass_test_module_from_wat(text)
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(0U))
  @ir.hot_verify_all_or_abort(func)
  let ctx = HotPassContext::new(
    ssa_nomerge_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) => return Err("ssa-nomerge hot-path run failed: \{err}")
  }
  let lowered = @ir.hot_lower_func_with_options(
    func,
    @ir.HotLowerOptions::new(preserve_dead_local_tee_drops=true),
  )
  let next_code_sec = match mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[0] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => return Err("expected code sec in hot-path fixture")
  }
  let out = mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => Ok(out)
    Err(err) => Err(@validate.validation_error_message(err))
  }
}

///|
test "ssa-nomerge preserves dropped local increments for later repair" {
  let source =
    #|(module
    #|  (func (local i32)
    #|    local.get 0
    #|    i32.const 1
    #|    i32.add
    #|    drop))
    #|)
  let optimized = match pass_test_run_pipeline(source, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected dropped increment ssa-nomerge success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("i32.add"), msg=text)
  assert_true(text.contains("drop"), msg=text)
}

///|
test "ssa-nomerge preserves typed loop-carried induction values" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32) (result i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    (local.get 0)
    #|    (loop $grow (type $loop_t)
    #|      local.tee 1
    #|      local.get 0
    #|      i32.lt_s
    #|      if (result i32)
    #|        local.get 1
    #|        i32.const 1
    #|        i32.shl
    #|        br $grow
    #|      else
    #|        local.get 1
    #|      end)))
    #|)
  let optimized = match pass_test_run_pipeline(source, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected typed loop ssa-nomerge success, got \{err}")
  }

  let (_, instrs) = try! ssa_test_first_defined_func(optimized)
  let text = instrs.to_string()
  assert_true(text.contains("local.tee"), msg=text)
  assert_true(text.contains("i32.shl"), msg=text)
}

///|
test "ssa-nomerge keeps straight-line local traffic on the canonical slot" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 5 local.set 0 local.get 0))",
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
}

///|
test "ssa-nomerge keeps the latest straight-line local alias live" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result f64) (local f64) f64.const 69 local.tee 0 drop f64.const 39 local.tee 0 drop local.get 0))",
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected straight-line alias replay success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::f64(),
      @lib.ValType::f64(),
      @lib.ValType::f64(),
    ]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::f64_const(@lib.F64(69.0)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::f64_const(@lib.F64(39.0)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(2U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  ])
}

///|
fn ssa_test_large_structured_branch_fixture() -> String {
  let out = StringBuilder::new()
  out.write_string("(module (func (local i32")
  for i = 0; i < 64; i = i + 1 {
    out.write_string(" i32")
  }
  out.write_string(") block i32.const 0 br 0 end i32.const 1 local.set 64))")
  out.to_string()
}

///|
test "ssa-nomerge skips large structured branch functions instead of hot fallback" {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      ssa_test_large_structured_branch_fixture(),
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected large structured ssa-nomerge skip success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=large-structured-local-writes",
      )
    }),
  )
}

///|
fn ssa_test_large_structured_local_write_fixture() -> String {
  let out = StringBuilder::new()
  out.write_string("(module (func (local i32) ")
  for i = 0; i < 130; i = i + 1 {
    out.write_string("i32.const 0 if nop else nop end ")
  }
  out.write_string("i32.const 1 local.set 0))")
  out.to_string()
}

///|
test "ssa-nomerge skips very large structured local-write functions without branches" {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      ssa_test_large_structured_local_write_fixture(),
      ["ssa-nomerge"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected large structured local-write ssa-nomerge skip success, got \{err}",
      )
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[ssa-nomerge]:skip-raw reason=large-structured-local-writes",
      )
    }),
  )
}

///|
test "ssa-nomerge rewrites dead param sets through fresh locals" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i64) (result i32) i64.const 756 local.set 0 i32.const 700))",
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dead param set rewrite success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i64()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::i64_const(@lib.I64(756L)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(700)),
  ])
}

///|
test "ssa-nomerge rewrites dead param tees through fresh locals" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param f64) (result f32) f64.const 17 local.tee 0 drop f32.const 92))",
      ["ssa-nomerge"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dead param tee rewrite success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::f64()]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::f64_const(@lib.F64(17.0)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::f32_const(@lib.F32::new(92.0)),
  ])
}

///|
test "ssa-nomerge keeps structured param writes on the canonical slot" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     i32.const 0
    #|     if
    #|       nop
    #|     else
    #|       nop
    #|     end
    #|     i32.const 1
    #|     if
    #|       nop
    #|     else
    #|       nop
    #|     end
    #|     i32.const 819
    #|     local.tee 0
    #|     drop
    #|     local.get 0))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected structured param slot reuse success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::nop()],
      Some([@lib.Instruction::nop()]),
    ),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [@lib.Instruction::nop()],
      Some([@lib.Instruction::nop()]),
    ),
    @lib.Instruction::i32_const(@lib.I32(819)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(0U)),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
}

///|
test "ssa-nomerge lowers branch joins through predecessor copies" {
  let input =
    #| (module
    #|   (func (result i32)
    #|     (local i32)
    #|     i32.const 1
    #|     local.set 0
    #|     i32.const 1
    #|     if
    #|       i32.const 7
    #|       local.set 0
    #|     else
    #|       nop
    #|     end
    #|     local.get 0))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected branch-join ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
      ],
      Some([
        @lib.Instruction::nop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
  ])
}

///|
test "ssa-nomerge lowers loop-carried locals before the backedge" {
  let input =
    #| (module
    #|   (func (result i32)
    #|     (local i32)
    #|     i32.const 1
    #|     local.set 0
    #|     block
    #|       loop
    #|         local.get 0
    #|         drop
    #|         i32.const 2
    #|         local.set 0
    #|         i32.const 1
    #|         br_if 0
    #|       end
    #|     end
    #|     local.get 0))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected loop-carried ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
          ]),
        ),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  ])
}

///|
test "ssa-nomerge skips synthetic entry copies for root loop headers" {
  let input =
    #| (module
    #|   (func (param i32)
    #|     (local i32)
    #|     loop
    #|       local.get 1
    #|       local.get 0
    #|       i32.lt_s
    #|       if
    #|         local.get 1
    #|         i32.const 1
    #|         i32.add
    #|         local.set 1
    #|         br 1
    #|       end
    #|     end))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected root-loop ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::loop_(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_lt_s(),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ],
          None,
        ),
      ]),
    ),
  ])
}

///|
test "ssa-nomerge rewrites structured early-return local traffic without hot lift" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     local.get 0
    #|     if
    #|       i32.const 7
    #|       local.set 1
    #|       local.get 1
    #|       return
    #|     else
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected structured raw ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::if_(
      @lib.BlockType::void_(),
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::return_(),
      ],
      Some([
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
  ])
}

///|
test "ssa-nomerge rewrites block-target branches through canonical locals" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     i32.const 0
    #|     local.set 1
    #|     block
    #|       local.get 0
    #|       if
    #|         i32.const 7
    #|         local.set 1
    #|         br 1
    #|       end
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected block-target raw ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ],
          None,
        ),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
}

///|
test "ssa-nomerge rewrites block-target br_if through canonical locals" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     i32.const 7
    #|     local.set 1
    #|     block
    #|       local.get 0
    #|       br_if 0
    #|       i32.const 9
    #|       local.set 1
    #|     end
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected block-target br_if raw ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::if_(
          @lib.BlockType::void_(),
          [
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
            @lib.Instruction::br(@lib.LabelIdx::new(1U)),
          ],
          None,
        ),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
      ]),
    ),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
  ])
}

///|
test "ssa-nomerge rewrites structured branch merges with result-typed ifs" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     (local i32)
    #|     i32.const 0
    #|     local.set 1
    #|     local.get 0
    #|     if (result i32)
    #|       i32.const 1
    #|       local.set 1
    #|       i32.const 7
    #|     else
    #|       i32.const 2
    #|       local.set 1
    #|       i32.const 9
    #|     end
    #|     drop
    #|     local.get 1))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected structured merge raw ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(2U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [
        @lib.Instruction::i32_const(@lib.I32(1)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(3U)),
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(6U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(6U)),
      ],
      Some([
        @lib.Instruction::i32_const(@lib.I32(2)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(7U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(5U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(7U)),
      ]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(5U)),
  ])
}

///|
test "ssa-nomerge keeps canonical param slots across typed if branch merges" {
  let input =
    #| (module
    #|   (func (param i32) (result i32)
    #|     local.get 0
    #|     if (result i32)
    #|       i32.const 7
    #|       local.set 0
    #|       i32.const 1
    #|     else
    #|       i32.const 9
    #|       local.set 0
    #|       i32.const 2
    #|     end
    #|     drop
    #|     local.get 0))
    #|
  let optimized = match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected typed-if param merge raw ssa-nomerge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(instrs, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::if_(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [
        @lib.Instruction::i32_const(@lib.I32(7)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(1)),
      ],
      Some([
        @lib.Instruction::i32_const(@lib.I32(9)),
        @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
        @lib.Instruction::i32_const(@lib.I32(2)),
      ]),
    ),
    @lib.Instruction::drop(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
  ])
}

///|
test "ssa-nomerge preserves unreachable compare carriers from func 523 shape" {
  let input =
    #| (module
    #|   (func (param i64) (result i32) (local i32 i64)
    #|     i32.const 7
    #|     local.set 1
    #|     block (result i64)
    #|       block
    #|         local.get 0
    #|         i64.const 1
    #|         i64.eq
    #|         if
    #|           i64.const 4
    #|           local.set 2
    #|           br 1
    #|         else
    #|           i32.const 0
    #|           return
    #|         end
    #|         unreachable
    #|       end
    #|       local.get 2
    #|     end
    #|     i64.const 0
    #|     i64.eq
    #|     if (result i32)
    #|       i32.const 1
    #|     else
    #|       local.get 2
    #|       i64.const 0
    #|       i64.gt_u
    #|     end))
    #|
  match pass_test_run_pipeline(input, ["ssa-nomerge"]) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected func 523 followup compare carrier shape to survive ssa-nomerge, got \{err}",
      )
  }
}

///|
test "ssa-nomerge hot path preserves Binaryen temp locals for unreachable dead tees" {
  let input =
    #| (module
    #|   (func (result i32)
    #|     (local i32)
    #|     block
    #|       unreachable
    #|     end
    #|     i32.const 7
    #|     local.tee 0
    #|     drop
    #|     i32.const 9))
    #|
  let optimized = match ssa_test_run_hot_path_only(input) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected unreachable dead tee hot-path success, got \{err}")
  }

  let (locals, instrs) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(instrs, [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    ),
    @lib.Instruction::i32_const(@lib.I32(7)),
    @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(9)),
  ])
}

///|
test "ssa-nomerge preserves unreachable dead tee temps before later control" {
  let input =
    #| (module
    #|   (func (param i32)
    #|     block
    #|       i32.const 1
    #|       br_table 0 0
    #|     end
    #|     block
    #|       unreachable
    #|     end
    #|     i32.const 7
    #|     local.tee 0
    #|     drop
    #|     block (result i32)
    #|       i32.const 1
    #|     end
    #|     drop
    #|     local.get 0
    #|     drop
    #|     block
    #|       i32.const 1
    #|       br_if 0
    #|     end
    #|     loop
    #|       i32.const 1
    #|       br_if 0
    #|     end
    #|     i32.const 1
    #|     if
    #|       block
    #|         br 0
    #|       end
    #|     else
    #|       nop
    #|     end))
    #|
  let optimized = match ssa_test_run_hot_path_only(input) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected unreachable dead tee temp preservation before later control, got \{err}",
      )
  }

  let (locals, _) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
}

///|
test "ssa-nomerge keeps canonical locals for if-result unreachable tee carriers" {
  let input =
    #| (module
    #|   (func (param f64 i32) (result i32)
    #|     block
    #|       i32.const 1
    #|       br_table 0 0
    #|     end
    #|     block
    #|       unreachable
    #|     end
    #|     i32.const 7
    #|     local.tee 1
    #|     drop
    #|     i32.const 11
    #|     i32.const 22
    #|     i32.const 1
    #|     select (result i32)
    #|     drop
    #|     i32.const 1
    #|     if (result i32)
    #|       i32.const 4
    #|     else
    #|       i32.const 58
    #|     end
    #|     drop
    #|     local.get 1
    #|     drop
    #|     block
    #|       i32.const 1
    #|       br_if 0
    #|     end
    #|     loop
    #|       i32.const 0
    #|       br_if 0
    #|     end
    #|     i32.const 0
    #|     if
    #|       block
    #|         br 0
    #|       end
    #|     else
    #|       nop
    #|     end
    #|     i32.const 869))
    #|
  let optimized = match ssa_test_run_hot_path_only(input) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected if-result unreachable tee-carrier success, got \{err}")
  }

  let (locals, _) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
}

///|
test "ssa-nomerge keeps canonical locals when unreachable reads stay behind later control blocks" {
  let input =
    #| (module
    #|   (func (result i32)
    #|     (local i32)
    #|     block
    #|       unreachable
    #|     end
    #|     i32.const 7
    #|     local.tee 0
    #|     drop
    #|     block
    #|       i32.const 1
    #|       br_if 0
    #|     end
    #|     loop
    #|       i32.const 1
    #|       br_if 0
    #|     end
    #|     i32.const 1
    #|     if
    #|       block
    #|         br 0
    #|       end
    #|     else
    #|       nop
    #|     end
    #|     local.get 0))
    #|
  let optimized = match ssa_test_run_hot_path_only(input) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected structured unreachable tee-carrier hot-path success, got \{err}",
      )
  }

  let (locals, _) = try! ssa_test_first_defined_func(optimized)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
}

///|
test "ssa-nomerge hot path validates unreachable default-local carrier followup" {
  let input =
    #| (module
    #|   (func (param i64 i64 i64) (result i64)
    #|     (local i64 i64 i64
    #|       i32 i32 i32 i32 i32 i32 i32 i32 i32 i32
    #|       i32 i32 i32 i32 i32 i32 i32 i32 i32 i32
    #|       i32 i32 i32 i32 i32 i32 i32 i32 i32 i32
    #|       i32 i32 i32 i32 i32 i32 i32 i32 i32 i32
    #|       i32 i32 i32 i32 i32 i32 i32 i32 i32 i32
    #|       i32 i32 i32 i32 i32 i32 i32 i32 i32 i32
    #|       i32 i32 i32 i32 i32)
    #|     i64.const 9
    #|     local.set 5
    #|     local.get 5
    #|     drop
    #|     block (result i64)
    #|       block
    #|         local.get 0
    #|         i64.const 1
    #|         i64.eq
    #|         if
    #|           i64.const 4
    #|           local.set 3
    #|           br 1
    #|         else
    #|           i64.const 0
    #|           return
    #|         end
    #|         unreachable
    #|       end
    #|       local.get 3
    #|     end
    #|     i64.const 0
    #|     i64.eq
    #|     if (result i32)
    #|       i32.const 1
    #|     else
    #|       local.get 4
    #|       local.get 2
    #|       i64.gt_u
    #|     end
    #|     drop
    #|     local.get 1
    #|     local.get 4
    #|     i64.or))
    #|
  match ssa_test_run_hot_path_only(input) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected hot-path-only ssa-nomerge carrier followup to validate, got \{err}",
      )
  }
}
