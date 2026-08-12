///|
fn simplify_locals_nostructure_test_many_i32_locals(count : Int) -> String {
  let out = StringBuilder::new()
  for i = 0; i < count; i = i + 1 {
    out.write_string(" (local i32)")
  }
  out.to_string()
}

///|
fn slns_test_block_type_is_nonvoid(block_type : @lib.BlockType) -> Bool {
  match block_type {
    @lib.VoidBlockType => false
    _ => true
  }
}

///|
fn slns_test_instrs_end_without_normal_value(
  instrs : Array[@lib.Instruction],
) -> Bool {
  if instrs.is_empty() {
    return false
  }
  match instrs[instrs.length() - 1] {
    @lib.Unreachable | @lib.Throw(_) | @lib.ThrowRef | @lib.Br(_) => true
    _ => false
  }
}

///|
fn slns_test_instr_has_nonvoid_no_normal_try_table(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.TryTable(block_type, _, @lib.Expr(body)) =>
      (
        slns_test_block_type_is_nonvoid(block_type) &&
        slns_test_instrs_end_without_normal_value(body)
      ) ||
      slns_test_instrs_have_nonvoid_no_normal_try_table(body)
    @lib.Block(_, @lib.Expr(body)) | @lib.Loop(_, @lib.Expr(body)) =>
      slns_test_instrs_have_nonvoid_no_normal_try_table(body)
    @lib.If(_, then_body, else_body) => {
      if slns_test_instrs_have_nonvoid_no_normal_try_table(then_body) {
        return true
      }
      match else_body {
        Some(body) => slns_test_instrs_have_nonvoid_no_normal_try_table(body)
        None => false
      }
    }
    _ => false
  }
}

///|
fn slns_test_instrs_have_nonvoid_no_normal_try_table(
  instrs : Array[@lib.Instruction],
) -> Bool {
  instrs.any(slns_test_instr_has_nonvoid_no_normal_try_table)
}

///|
fn slns_test_module_has_nonvoid_no_normal_try_table(mod_ : @lib.Module) -> Bool {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      funcs.any(fn(func) {
        let @lib.Func(_, @lib.Expr(body)) = func
        slns_test_instrs_have_nonvoid_no_normal_try_table(body)
      })
    None => false
  }
}

///|
fn slns_test_deep_result_if_local_tee_chain(depth : Int) -> String {
  let out = StringBuilder::new()
  out.write_string(
    "(module (memory 1) (func (param i32) (result i32) (local i32) local.get 0 i32.load local.tee 1 ",
  )
  for i = 0; i < depth; i = i + 1 {
    out.write_string(
      "i32.const \{61 + i} i32.eq if (result i32) i32.const 1 else ",
    )
    if i + 1 < depth {
      out.write_string("local.get 1 ")
    }
  }
  out.write_string("i32.const 0 ")
  for close_i = 0; close_i < depth; close_i = close_i + 1 {
    out.write_string("end ")
  }
  out.write_string("))")
  out.to_string()
}

///|
fn slns_test_deep_result_if_many_local_write_chain(
  depth : Int,
  local_count : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string("(module (func (param i32) (result i32) ")
  out.write_string(
    simplify_locals_nostructure_test_many_i32_locals(local_count),
  )
  out.write_string(" local.get 0 local.set 1 local.get 1 ")
  for i = 0; i < depth; i = i + 1 {
    out.write_string(
      "i32.const \{100 + i} i32.ge_s if (result i32) i32.const 1 else ",
    )
    if i + 1 < depth {
      out.write_string("local.get 1 ")
    }
  }
  out.write_string("i32.const 0 ")
  for close_i = 0; close_i < depth; close_i = close_i + 1 {
    out.write_string("end ")
  }
  out.write_string("))")
  out.to_string()
}

///|
fn slns_test_many_result_if_local_write(count : Int) -> String {
  let out = StringBuilder::new()
  out.write_string(
    "(module (func (param i32) (result i32) (local i32) local.get 0 local.set 1 ",
  )
  for i = 0; i < count; i = i + 1 {
    out.write_string(
      "local.get 1 i32.const \{i} i32.ge_s if (result i32) i32.const 1 else i32.const 0 end drop ",
    )
  }
  out.write_string("local.get 1))")
  out.to_string()
}

///|
fn slns_test_deep_br_table_local_write(depth : Int) -> String {
  let out = StringBuilder::new()
  out.write_string(
    "(module (func (param i32) (result i32) (local i32) local.get 0 local.set 1 ",
  )
  for _i = 0; _i < depth; _i = _i + 1 {
    out.write_string("block ")
  }
  out.write_string("local.get 1 br_table ")
  for label = 0; label < depth; label = label + 1 {
    out.write_string("\{label} ")
  }
  for _i = 0; _i < depth; _i = _i + 1 {
    out.write_string("end ")
  }
  out.write_string("local.get 1))")
  out.to_string()
}

///|
fn slns_test_deep_block_local_write(depth : Int, local_count : Int) -> String {
  let out = StringBuilder::new()
  out.write_string("(module (func (param i32) (result i32) ")
  out.write_string(
    simplify_locals_nostructure_test_many_i32_locals(local_count),
  )
  out.write_string(" local.get 0 local.set 1 ")
  for _i = 0; _i < depth; _i = _i + 1 {
    out.write_string("block ")
  }
  for _i = 0; _i < depth; _i = _i + 1 {
    out.write_string("local.get 1 br 0 end ")
  }
  out.write_string("local.get 1))")
  out.to_string()
}

///|
test "simplify-locals defers call-result locals beside memory copy" {
  let input =
    #|(module
    #|  (memory 1)
    #|  (func $alloc (param i32 i32) (result i32) local.get 0)
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    i32.const 2
    #|    call $alloc
    #|    local.set 1
    #|    local.get 1
    #|    i32.const 0
    #|    local.get 0
    #|    memory.copy))
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected call-result memory-copy success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=call-bulk-memory-effect-order-simplify-locals-nostructure-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-nostructure defers call-result locals beside memory copy" {
  let input =
    #|(module
    #|  (memory 1)
    #|  (func $alloc (param i32 i32) (result i32) local.get 0)
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    i32.const 2
    #|    call $alloc
    #|    local.set 1
    #|    local.get 1
    #|    i32.const 0
    #|    local.get 0
    #|    memory.copy))
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected call-result memory-copy success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=call-bulk-memory-effect-order-simplify-locals-nostructure-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals preserves loaded loop locals across exits" {
  let input =
    #|(module
    #|  (memory 1)
    #|  (func (param i32) (result i32) (local i32)
    #|    block
    #|      loop
    #|        local.get 0
    #|        i32.load
    #|        local.set 1
    #|        local.get 1
    #|        i32.const 0
    #|        i32.eq
    #|        br_if 1
    #|        br 0
    #|      end
    #|    end
    #|    local.get 1))
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected loaded loop-local success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=self-update-loop-local-lifetime")
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals preserves additive self-updated loop locals" {
  let input =
    #|(module
    #|  (func (param i32) (result i32)
    #|    block
    #|      loop
    #|        local.get 0
    #|        i32.const 2
    #|        i32.add
    #|        local.set 0
    #|        local.get 0
    #|        local.set 0
    #|        br 1
    #|      end
    #|    end
    #|    local.get 0))
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected additive self-update loop success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=self-update-loop-local-lifetime")
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-nostructure preserves additive self-updated loop locals" {
  let input =
    #|(module
    #|  (func (param i32) (result i32)
    #|    block
    #|      loop
    #|        local.get 0
    #|        i32.const 2
    #|        i32.add
    #|        local.set 0
    #|        local.get 0
    #|        local.set 0
    #|        br 1
    #|      end
    #|    end
    #|    local.get 0))
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected additive self-update loop success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=self-update-loop-local-lifetime")
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-nostructure preserves self-updated loop locals" {
  let input =
    #|(module
    #|  (func (param i32) (result i32)
    #|    block
    #|      loop
    #|        local.get 0
    #|        i32.const 4
    #|        i32.sub
    #|        local.set 0
    #|        local.get 0
    #|        i32.const 4
    #|        i32.ge_u
    #|        br_if 0
    #|      end
    #|    end
    #|    local.get 0))
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected self-update loop success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=self-update-loop-local-lifetime")
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals preserves parameter-initialized block-result loop carriers" {
  let input =
    #|(module
    #|  (memory 1)
    #|  (func (param i32 i32) (result i32) (local i32 i32 i32 i32)
    #|    local.get 0
    #|    i32.load offset=4 align=1
    #|    local.set 2
    #|    local.get 1
    #|    local.get 2
    #|    i32.le_s
    #|    if (result i32)
    #|      local.get 1
    #|      local.set 3
    #|      loop
    #|        block
    #|          block (result i32)
    #|            local.get 2
    #|            local.get 3
    #|            local.tee 4
    #|            i32.gt_s
    #|            if
    #|              local.get 0
    #|              i32.load align=1
    #|              local.set 5
    #|              nop
    #|              local.get 4
    #|              i32.const 1
    #|              i32.add
    #|              br 1
    #|            end
    #|            br 1
    #|          end
    #|          local.set 3
    #|          br 1
    #|        end
    #|      end
    #|      unreachable
    #|    else
    #|      i32.const 0
    #|    end))
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected block-result loop carrier success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=parameter-initialized-block-result-loop-carrier")
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-nostructure preserves consumers before conditional releases" {
  let input =
    #|(module
    #|  (memory 1)
    #|  (func $make (result i32) i32.const 1)
    #|  (func $use (param i32 i32) (result i32) local.get 0)
    #|  (func $release-left (param i32))
    #|  (func $release-right (param i32))
    #|  (func (param i32) (result i32) (local i32 i32 i32)
    #|    local.get 0
    #|    i32.load
    #|    local.set 1
    #|    call $make
    #|    local.tee 3
    #|    local.set 2
    #|    local.get 1
    #|    local.get 2
    #|    call $use
    #|    local.get 1
    #|    if
    #|      local.get 1
    #|      call $release-left
    #|    end
    #|    local.get 2
    #|    if
    #|      local.get 2
    #|      call $release-right
    #|    end))
  let original = pass_test_module_from_wat(input)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected conditional release ordering success, got \{err}")
  }
  @debug.assert_eq(optimized, original)
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=call-argument-structured-release-simplify-locals-nostructure-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals preserves consumers before distinct conditional releases" {
  let input =
    #|(module
    #|  (memory 1)
    #|  (func $make (result i32) i32.const 1)
    #|  (func $use (param i32 i32) (result i32) local.get 0)
    #|  (func $release-left (param i32))
    #|  (func $release-right (param i32))
    #|  (func (param i32) (result i32) (local i32 i32 i32)
    #|    local.get 0
    #|    i32.load
    #|    local.set 1
    #|    call $make
    #|    local.tee 3
    #|    local.set 2
    #|    local.get 1
    #|    local.get 2
    #|    call $use
    #|    local.get 1
    #|    if
    #|      local.get 1
    #|      call $release-left
    #|    end
    #|    local.get 2
    #|    if
    #|      local.get 2
    #|      call $release-right
    #|    end))
  let original = pass_test_module_from_wat(input)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected conditional release ordering success, got \{err}")
  }
  @debug.assert_eq(optimized, original)
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=call-argument-structured-release-simplify-locals-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals variants preserve result locals until a consumer before release" {
  let input =
    #|(module
    #|  (func $use (param i32 i32 i32 i32 i32) (result i32) i32.const 0)
    #|  (func $release (param i32))
    #|  (func (param i32 i32 i32 i32 i32) (result i32) (local i32 i32 i32 i32)
    #|    local.get 4
    #|    if (result i32)
    #|      i32.const 1
    #|    else
    #|      i32.const 2
    #|    end
    #|    local.set 5
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    local.get 3
    #|    local.get 5
    #|    call $use
    #|    local.get 5
    #|    call $release))
  let original = pass_test_module_from_wat(input)
  for pass_name in ["simplify-locals-nostructure", "simplify-locals"] {
    let trace : Array[String] = []
    let optimized = match
      pass_test_run_pipeline(
        input,
        [pass_name],
        options=HotPipelineOptions::new(
          trace=Some(fn(line) { trace.push(line) }),
        ),
      ) {
      Ok(mod_) => mod_
      Err(err) =>
        fail("expected result-local lifetime preservation, got \{err}")
    }
    @debug.assert_eq(
      optimized.pretty_print_func(@lib.FuncIdx::new(2U)),
      original.pretty_print_func(@lib.FuncIdx::new(2U)),
    )
    assert_true(
      trace.any(fn(line) {
        line.contains(
          "reason=single-argument-distinct-call-lifetime-\{pass_name}-noop",
        )
      }),
      msg=trace.to_string(),
    )
  }
}

///|
test "simplify-locals preserves stack-carried overwritten locals" {
  let input =
    #|(module
    #|  (func $use (param i32 i32))
    #|  (func (param i32 i32) (local i32)
    #|    local.get 0
    #|    local.set 2
    #|    local.get 2
    #|    local.get 1
    #|    local.set 2
    #|    local.get 2
    #|    call $use))
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected overwritten-local carrier success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=stack-carried-overwritten-local")
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals preserves a conditional call result reloaded from a parameter" {
  let input =
    #|(module
    #|  (func $prepare (param i32) (result i32) local.get 0)
    #|  (func $replace (param i32))
    #|  (func $lookup (param i32) (result i32) i32.const 7)
    #|  (func $consume (param i32))
    #|  (func (param i32 i32) (result i32) (local i32 i32 i32)
    #|    local.get 1
    #|    call $prepare
    #|    local.set 3
    #|    local.get 0
    #|    call $lookup
    #|    local.tee 1
    #|    i32.eqz
    #|    local.tee 2
    #|    if
    #|      local.get 3
    #|      call $replace
    #|      local.get 0
    #|      call $lookup
    #|      local.set 1
    #|      local.get 1
    #|      i32.eqz
    #|      if
    #|        unreachable
    #|      end
    #|    end
    #|    local.get 1
    #|    call $consume
    #|    local.get 1
    #|    return))
  let original = pass_test_module_from_wat(input)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["simplify-locals"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected conditional call-result reload success, got \{err}")
  }
  @debug.assert_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(4U)),
    original.pretty_print_func(@lib.FuncIdx::new(4U)),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=call-result-structured-lifetime")
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-nostructure preserves stack-carried overwritten locals" {
  let input =
    #|(module
    #|  (func $use (param i32 i32))
    #|  (func (param i32 i32) (local i32)
    #|    local.get 0
    #|    local.set 2
    #|    local.get 2
    #|    local.get 1
    #|    local.set 2
    #|    local.get 2
    #|    call $use))
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      input,
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected overwritten-local carrier success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=stack-carried-overwritten-local")
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-nostructure treats NaN constants as unchanged" {
  // Structural equality is not reflexive for NaN-bearing instructions. Both
  // variants must converge without treating a byte-identical lowered cleanup
  // result as fresh progress.
  for pass_name in ["simplify-locals-nostructure", "simplify-locals"] {
    let optimized = match
      pass_test_run_pipeline(
        "(module (func f32.const nan i32.trunc_f32_s drop unreachable))",
        [pass_name],
      ) {
      Ok(mod_) => mod_
      Err(err) => fail("expected \{pass_name} NaN convergence, got \{err}")
    }
    let pretty = optimized.pretty_print_defined_func(0U)
    assert_true(pretty.contains("F32(NaN)"), msg=pretty)
    assert_true(pretty.contains("i32.trunc_f32s"), msg=pretty)
  }
}

///|
test "simplify-locals-nostructure skips redundant second main cycle without deferred writes" {
  // Performance invariant from the SLNS v130 timing audit: a function with no
  // first-cycle-deferred multi-use local.set work should not rescan the root
  // region a second time after a no-change first main/dead-cleanup pass.
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  match
    pass_test_run_pipeline(
      "(module (func (param i32) (local i32) local.get 0 if i32.const 1 local.set 1 end local.get 1 drop))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure no-deferred perf fixture success, got \{err}",
      )
  }
  let main_cycles = lines.filter(fn(line) {
    line.contains("perf:timer name=detail:simplify-locals:main-cycle")
  })
  @debug.assert_eq(main_cycles.length(), 1)
}

///|
test "simplify-locals-nostructure skips changed first-cycle follow-up without deferred writes" {
  // Binaryen's second main cycle exists for deferred multi-use tee work. A
  // straight-line single-use sink mutates the function but has no deferred
  // multi-use local.set, so the pass should not pay for a second full root scan.
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 7 local.set 0 local.get 0))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure changed no-deferred perf fixture success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
  let main_cycles = lines.filter(fn(line) {
    line.contains("perf:timer name=detail:simplify-locals:main-cycle")
  })
  @debug.assert_eq(main_cycles.length(), 1)
}

///|
test "simplify-locals-nostructure batches direct writeback validation" {
  // Production modules can contain thousands of independently changed
  // functions. Validate that changed-function set once instead of rebuilding
  // the same module validation context after every function rewrite.
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 7 local.set 0 local.get 0) (func (result i32) (local i32) i32.const 9 local.set 0 local.get 0))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure batch writeback fixture success, got \{err}",
      )
  }
  for func_idx in [0U, 1U] {
    let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(func_idx))
    assert_false(pretty.contains("local.set"), msg=pretty)
    assert_false(pretty.contains("local.get"), msg=pretty)
  }
  assert_true(
    lines.any(fn(line) {
      line.contains(
        "perf:timer name=guard:simplify-locals-nostructure-writeback-batch",
      )
    }),
    msg=lines.join("\n"),
  )
}

///|
test "simplify-locals-nostructure defers repeated-local writes by aggregate use count" {
  // Binaryen uses the whole-local get count on the first cycle. Even though
  // each definition below has one following read, both writes are deferred so
  // the later cycle can form tee/set traffic and remove the final pure write.
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (local i32) i32.const 1 local.set 0 local.get 0 drop i32.const 2 local.set 0 local.get 0 drop))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure deferred multi-use perf fixture success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
  let main_cycles = lines.filter(fn(line) {
    line.contains("perf:timer name=detail:simplify-locals:main-cycle")
  })
  @debug.assert_eq(main_cycles.length(), 2)
}

///|
test "simplify-locals-nostructure keeps high-frequency subphase timers off the trace hot path" {
  // Performance invariant from the SLNS v130 timing audit: the outer pass timer
  // includes trace emission overhead, so per-cycle subphase timer lines distort
  // pass-local timings on tiny generated functions. Keep the cycle-count timer
  // visible for loop-shape invariants, but avoid emitting the high-frequency
  // inner scan/dead/delete timer lines on each cycle.
  let lines : Array[String] = []
  let trace = fn(line) { lines.push(line) }
  let perf = HotPerfSession::new(trace~, dump_options=HotPerfDumpOptions::new())
  match
    pass_test_run_pipeline(
      "(module (func (local i32) i32.const 1 local.set 0 local.get 0 drop i32.const 2 local.set 0 local.get 0 drop))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(trace), perf=Some(perf)),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure subphase timer overhead fixture success, got \{err}",
      )
  }
  assert_false(
    lines.any(fn(line) {
      line.contains("perf:timer name=detail:simplify-locals:scan-root-region") ||
      line.contains("perf:timer name=detail:simplify-locals:count-local-gets") ||
      line.contains(
        "perf:timer name=detail:simplify-locals:delete-main-detached",
      ) ||
      line.contains("perf:timer name=detail:simplify-locals:dead-cleanup") ||
      line.contains(
        "perf:timer name=detail:simplify-locals:delete-dead-detached",
      )
    }),
    msg=lines.join("\n"),
  )
}

///|
test "simplify-locals-nostructure sinks straight-line single-use sets" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 7 local.set 0 local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-nostructure success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure optimizes unrelated locals when an existing tee is present" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32 i32) i32.const 1 local.tee 0 drop i32.const 7 local.set 1 local.get 1))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure existing-tee success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-nostructure optimizes root existing tee with later control" {
  // Binaryen version_130 keeps the control boundary but still removes the
  // dropped root tee and sinks the unrelated local. The remaining Starshine
  // structured-control tee guard must stay narrow enough to allow this shape.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) i32.const 1 local.tee 1 drop local.get 0 if nop end i32.const 7 local.set 2 local.get 2))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure root-tee/control success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if (Void)"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
}

///|
test "simplify-locals-nostructure optimizes unrelated root locals with embedded control tee" {
  // Binaryen version_130 can clean unrelated root-level local traffic even when
  // a dropped `local.tee` appears inside a structured-control child. Starshine
  // must not skip the whole function for the embedded tee. This test only
  // requires the unrelated root cleanup; separate safety fixtures keep used
  // structured-control tees from being deleted.
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) local.get 0 if i32.const 7 local.tee 1 drop end i32.const 42 local.set 2 local.get 2))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure embedded tee root cleanup success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if (Void)"), msg=pretty)
  assert_true(pretty.contains("I32(42)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals-nostructure]:skip-hot reason=control-local-tee-hazard-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-nostructure bounds deep result-if local-tee convergence" {
  // A production parser classifier contains a local.tee feeding a long nested
  // result-if equality chain. The generic protected-tee cleanup revisits that
  // path exponentially; fail closed before HOT lift at the pass-owned depth
  // boundary while preserving ordinary shallow structured-tee cleanup.
  let input = slns_test_deep_result_if_local_tee_chain(12)
  let original = pass_test_module_from_wat(input)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure deep result-if convergence success, got \{err}",
      )
  }
  @debug.assert_eq(optimized, original)
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals-nostructure]:skip-raw reason=deep-result-if-local-tee-convergence",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-nostructure bounds deep result-if many-local convergence" {
  // Large generated classifiers combine many local carriers with nested
  // result-if ladders. The protected root cleanup otherwise revisits those
  // ladders combinatorially even without an existing local.tee.
  let input = slns_test_deep_result_if_many_local_write_chain(12, 32)
  let original = pass_test_module_from_wat(input)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure many-local result-if convergence success, got \{err}",
      )
  }
  @debug.assert_eq(optimized, original)
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals-nostructure]:skip-raw reason=deep-result-if-many-local-write-convergence",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-nostructure bounds many result-if local-write convergence" {
  // Generated classifiers can contain several moderate-depth result-if
  // ladders rather than one chain deep enough for the depth guard. Bound their
  // aggregate path-sensitive cleanup while retaining smaller classifiers.
  let input = slns_test_many_result_if_local_write(16)
  let original = pass_test_module_from_wat(input)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure many result-if convergence success, got \{err}",
      )
  }
  @debug.assert_eq(optimized, original)
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals-nostructure]:skip-raw reason=many-result-if-local-write-convergence",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-nostructure bounds deep block local-write convergence" {
  // Flattened json-as dispatch classifiers can contain a single local write and
  // dozens of nested block exits. The no-structure root scan is combinatorial on
  // this intentionally unsupported shape, so preserve it before HOT lifting.
  let input = slns_test_deep_block_local_write(64, 129)
  let original = pass_test_module_from_wat(input)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure deep block convergence success, got \{err}",
      )
  }
  @debug.assert_eq(optimized, original)
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals-nostructure]:skip-raw reason=deep-block-local-write-convergence",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-nostructure bounds deep br-table local-write convergence" {
  // A production classifier lowers to dozens of nested blocks around a
  // br_table and local carriers. Bound that recursive HOT path by structural
  // depth, not module/function cardinality.
  let input = slns_test_deep_br_table_local_write(24)
  let original = pass_test_module_from_wat(input)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure deep br-table convergence success, got \{err}",
      )
  }
  @debug.assert_eq(optimized, original)
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals-nostructure]:skip-raw reason=deep-br-table-local-write-convergence",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-nostructure removes dead result-if set with embedded tee" {
  // The protected embedded-tee path must still do safe child-local dead-set
  // cleanup for a dropped result `if`: Binaryen removes the unused Local 2 write
  // while preserving the sibling Local 3 write and the later embedded tee hazard.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (local i32 i32 i32) local.get 0 if (result i32) i32.const 20 local.set 2 i32.const 2 else i32.const 30 local.set 3 i32.const 3 end drop local.get 3 if i32.const 120 local.tee 3 drop end local.get 3 drop))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure embedded tee dead result-if cleanup success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if I32"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 3)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 3)"), msg=pretty)
}

///|
test "simplify-locals-nostructure removes an embedded tee carrier observed only by drop" {
  // Lowering `drop(local.tee)` inside structured control exposes a plain set.
  // Once the later root read is also proven pure and dropped, the entire local
  // carrier is dead and can be removed without broad child deletion.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (local i32) local.get 0 if i32.const 120 local.tee 1 drop end local.get 1 drop))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure embedded dropped-tee success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if (Void)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.tee (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-nostructure optimizes deferred root locals with embedded control tee" {
  // The protected embedded-control-tee path still needs Binaryen's later-cycle
  // root cleanup for deferred multi-use locals. This is safe root traffic: the
  // structured-control child containing the tee remains protected.
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (local i32 i32) i32.const 1 local.set 1 local.get 1 drop i32.const 2 local.set 1 local.get 1 drop local.get 0 if i32.const 7 local.tee 2 drop end))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure embedded tee deferred-root cleanup success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("if (Void)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals-nostructure]:skip-hot reason=control-local-tee-hazard-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-nostructure removes the dead transparent copy chain" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (local i32 i32 i32) local.get 0 local.set 1 block local.get 1 local.set 2 end local.get 2 local.set 1 local.get 1 drop local.get 0 drop))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals-nostructure copy cleanup, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  @debug.assert_eq(pretty.split("local.get (Local 0)").length(), 1)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
}

///|
test "simplify-locals-nostructure optimizes pure local traffic before root calls" {
  // Binaryen version_130 optimizes the local carrier before the structured
  // control and root call. The root stack/local-set hazard guard must stay
  // narrow enough to protect call-valued local writes without blocking this
  // pure pre-call local traffic.
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $side) (func (param i32) (local i32) i32.const 50 local.set 1 local.get 1 drop local.get 0 if nop end call $side))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure pre-call local cleanup success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("I32(50)"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("if (Void)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals-nostructure]:skip-hot reason=root-local-set-stack-hazard-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-nostructure carries pure tee candidate across value block call argument" {
  // Binaryen version_130 treats a branch-free value block in an earlier call
  // argument as a linear expression boundary for pure pending locals: the later
  // multi-use `local.get` becomes the first `local.tee` use rather than forcing
  // the original `local.set` / `local.get` carrier to remain.
  let optimized = match
    pass_test_run_pipeline(
      "(module (import \"env\" \"f\" (func $f (param i31ref i32))) (func (local i32) i32.const 50 local.set 0 block (result i31ref) ref.null i31 end local.get 0 call $f local.get 0 drop))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure value-block call-arg success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("local.tee (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
}

///|
test "no-structure variants sink pure locals past an unrelated throwing try_table boundary" {
  let input = "(module (type $t (func)) (tag $e (type $t)) (func $value (result i32) i32.const 3) (func (local i32 i32) call $value local.set 0 block try_table (catch $e 0) local.get 0 drop end end i32.const 7 local.set 1 block try_table (catch $e 0) local.get 1 drop end end))"
  for
    pass_name in [
      "simplify-locals-nostructure", "simplify-locals-notee-nostructure",
    ] {
    let pretty = match pass_test_run_pipeline(input, [pass_name]) {
      Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(1U))
      Err(err) => fail("expected \{pass_name} try_table success, got \{err}")
    }
    assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
    assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
    assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
    assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
    assert_true(pretty.contains("I32(7)"), msg=pretty)
  }
}

///|
test "simplify-locals-nostructure sinks call-valued locals into later call operands" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $alloc (param i32 i32) (result i32) (local.get 0)) (func (param i32 i32) (local i32) local.get 0 i32.const 2 call $alloc local.set 2 local.get 2 local.get 1 call $alloc drop))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure stack/local-set hazard success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
  assert_false(
    trace.any(fn(line) { line.contains("root-local-set-stack-hazard-noop") }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-nostructure preserves call result across indirect and direct call uses" {
  let input =
    #|(module
    #|  (type $use-type (func (param i32 i32) (result i32)))
    #|  (table 1 funcref)
    #|  (elem (i32.const 0) $use)
    #|  (func $make (result i32) i32.const 1)
    #|  (func $use (type $use-type) local.get 0)
    #|  (func $release (param i32))
    #|  (func (param i32) (local i32)
    #|    call $make
    #|    local.set 1
    #|    local.get 0
    #|    local.get 1
    #|    i32.const 0
    #|    call_indirect (type $use-type)
    #|    drop
    #|    local.get 1
    #|    call $release))
  let original = pass_test_module_from_wat(input)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure ordered call lifetime success, got \{err}",
      )
  }
  @debug.assert_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(3U)),
    original.pretty_print_func(@lib.FuncIdx::new(3U)),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=call-result-multi-call-lifetime")
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-notee-nostructure sinks single-use call-valued locals" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $alloc (param i32 i32) (result i32) (local.get 0)) (func (param i32 i32) (local i32) local.get 0 i32.const 2 call $alloc local.set 2 local.get 2 local.get 1 call $alloc drop))",
      ["simplify-locals-notee-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-notee-nostructure stack/local-set hazard success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
  assert_false(
    trace.any(fn(line) { line.contains("root-local-set-stack-hazard-noop") }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-notee-nostructure accepts O4z spelling" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 7 local.set 0 local.get 0))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals-notee-nostructure success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure drops overwritten pending load set" {
  // Binaryen version_130 converts the first overwritten set into
  // `drop(i32.load ...)` to preserve trap timing and sinks the final load into
  // the single use. This specifically covers the overwritten-pending-set family
  // without using the currently guarded root call/stack-effect hazard surface.
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i32) (local i32) i32.const 0 i32.load local.set 0 i32.const 4 i32.load local.set 0 local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure overwritten-load success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("load"), msg=pretty)
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure drops overwritten pending load set" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i32) (local i32) i32.const 0 i32.load local.set 0 i32.const 4 i32.load local.set 0 local.get 0))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-notee-nostructure overwritten-load success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("load"), msg=pretty)
  assert_true(pretty.contains("I32(4)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure removes pure zero-read sets" {
  // Binaryen version_130 final dead-set cleanup erases a zero-read pure set in
  // both canonical and no-tee no-structure variants, leaving only inert debris.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (local i32) i32.const 7 local.set 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure pure dead-set success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure removes pure zero-read sets" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (local i32) i32.const 7 local.set 0))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-notee-nostructure pure dead-set success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure removes zero-read stack set after unreachable" {
  // Binaryen version_130 removes a zero-read local.set after an unreachable
  // stack producer. This is a focused bottom/unreachable cleanup shape: the set
  // has no material child value in HOT, but the preceding nonfallthrough root
  // makes removing the stack-style consumer safe and keeps the optimized module
  // valid.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) unreachable local.set 0 i32.const 1))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure unreachable dead-set success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure removes zero-read stack set after unreachable" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) unreachable local.set 0 i32.const 1))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-notee-nostructure unreachable dead-set success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure flattens no-normal result block before tail unreachable" {
  // Binaryen version_130 rewrites a result block that cannot complete normally
  // before a tail unreachable into flat dropped side-effect/value debris. The
  // flattened raw shape then canonicalizes without the extra `drop(unreachable)`
  // seen in wasm-smith case-009332.
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (result i32) memory.size block (result i32) f64.const 1 unreachable end unreachable))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure no-normal result-block flattening success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("F64(1)"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("block I32"), msg=pretty)
}

///|
test "simplify-locals-nostructure reorders const nop in nested result loops" {
  // wasm-smith case-003694 has no local writes, but Binaryen version_130 still
  // runs enough SLNS cleanup to move a pure const after inert `nop` debris in a
  // nested result-loop body. Leaving the input unchanged makes the compare
  // harness canonicalization synthesize a local.set/local.get carrier instead.
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (type $t (func (result f64))) (func (type $t) loop (type $t) loop (type $t) f64.const 1 nop end end))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure result-loop const/nop reorder success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(
    pretty.contains("nopnop(f64.const F64(1))"),
    msg="\{pretty}\ntrace=\{trace}",
  )
}

///|
test "simplify-locals-nostructure drops trapping zero-read sets" {
  // Binaryen version_130 removes the dead local carrier while preserving the
  // load as a drop so its possible trap remains in place.
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (local i32) i32.const 0 i32.load local.set 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure trapping dead-set success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("load"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure drops trapping zero-read sets" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (local i32) i32.const 0 i32.load local.set 0))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-notee-nostructure trapping dead-set success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("load"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure drops call-valued zero-read sets" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $side (result i32) i32.const 42) (func (local i32) call $side local.set 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure call dead-set success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure drops call-valued zero-read sets" {
  // The no-tee sibling keeps tee creation disabled but still runs final dead-set
  // cleanup, preserving the call side effect as a drop.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $side (result i32) i32.const 42) (func (local i32) call $side local.set 0))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-notee-nostructure call dead-set success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure removes dead copy after equivalent-get cleanup" {
  // Binaryen version_130 canonical SLNS rewrites the surviving copied-local use
  // back to the source param, then final dead-set cleanup removes both copy
  // carriers.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) local.get 0 local.set 1 local.get 1 local.set 2 local.get 1))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure dead-copy cleanup success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure removes dead copy without creating tees" {
  // Binaryen version_130 no-tee SLNS removes the zero-read copy to Local 2 but
  // leaves the Local 1 copy carrier. Starshine performs the same final dead-set
  // cleanup and additionally canonicalizes the pure Local 1 copy back to the
  // source param without creating a tee or synthesizing structure. That is a
  // narrow no-tee Starshine win: fewer local ops for an effect-free copy chain.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) local.get 0 local.set 1 local.get 1 local.set 2 local.get 1))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-notee-nostructure dead-copy cleanup success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.tee"), msg=pretty)
}

///|
test "simplify-locals-nostructure drops overwritten pending call set" {
  // Binaryen version_130 preserves the overwritten call's side effect as
  // `drop(call $a)`, erases the dead first write, and sinks the final call to
  // the result. This is the call-valued overwritten-set surface that used to be
  // hidden behind the root stack/local-set hazard guard.
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $a (result i32) i32.const 1) (func $b (result i32) i32.const 2) (func (result i32) (local i32) call $a local.set 0 call $b local.set 0 local.get 0))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure overwritten-call success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals-nostructure]:skip-hot reason=root-local-set-stack-hazard-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-notee-nostructure drops overwritten pending call set" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $a (result i32) i32.const 1) (func $b (result i32) i32.const 2) (func (result i32) (local i32) call $a local.set 0 call $b local.set 0 local.get 0))",
      ["simplify-locals-notee-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-notee-nostructure overwritten-call success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[simplify-locals-notee-nostructure]:skip-hot reason=root-local-set-stack-hazard-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-nostructure sinks nonthrowing set into try_table body" {
  // `try_table` has the same throwing-value barrier as `try`: pure values may
  // sink into the body, but throwing values must not move inside the handler.
  let optimized = match
    pass_test_run_pipeline(
      "(module (tag $e (param i32)) (func (result i32) (local i32) i32.const 7 local.set 0 (block $h (result i32) (try_table (result i32) (catch $e $h) local.get 0))))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure try_table sink success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("try_table I32"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure sinks global.get across unrelated global.set" {
  // Binaryen version_130 treats distinct globals independently for SLNS motion:
  // a pending read of `$g` may sink across a write to `$h`, but not across a
  // write to `$g`. This locks the safe positive half of the effect/order row.
  let optimized = match
    pass_test_run_pipeline(
      "(module (global $g (mut i32) (i32.const 1)) (global $h (mut i32) (i32.const 2)) (func (result i32) (local i32) global.get $g local.set 0 i32.const 9 global.set $h local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure distinct-global success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure keeps global.get before same-global set" {
  // The same Binaryen probe keeps the local when the intervening global.set
  // writes the global that the pending value reads.
  let optimized = match
    pass_test_run_pipeline(
      "(module (global $g (mut i32) (i32.const 1)) (func (result i32) (local i32) global.get $g local.set 0 i32.const 9 global.set $g local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure same-global success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure sinks dynamic read-only loads" {
  // Binaryen version_130 allows two dynamic read-only trapping loads to commute:
  // the dropped later load stays as a drop, while the earlier pending load can
  // sink to the final use. This failed before Starshine allowed narrow one-use
  // Load movement for parameter-address read-only loads.
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (param i32 i32) (result i32) (local i32) local.get 0 i32.load local.set 2 local.get 1 i32.load drop local.get 2))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals-nostructure load/load success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("load"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
}

///|
test "simplify-locals-nostructure keeps table.get before same table.set" {
  // Binaryen version_130 keeps the local carrier for table.get across a table
  // write to the same table; table write barriers are still conservative.
  let optimized = match
    pass_test_run_pipeline(
      "(module (table $t0 10 funcref) (func (result funcref) (local funcref) i32.const 0 table.get $t0 local.set 0 i32.const 0 ref.null func table.set $t0 local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure same-table success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.get"), msg=pretty)
  assert_true(pretty.contains("table.set"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure keeps table.get before distinct table.set" {
  // A current Binaryen version_130 probe also keeps the carrier across a write
  // to a different table. Record that as a Binaryen-stationary boundary, not an
  // exact-table positive to implement.
  let optimized = match
    pass_test_run_pipeline(
      "(module (table $t0 10 funcref) (table $t1 10 funcref) (func (result funcref) (local funcref) i32.const 0 table.get $t0 local.set 0 i32.const 0 ref.null func table.set $t1 local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure distinct-table success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("table.get"), msg=pretty)
  assert_true(pretty.contains("table.set"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure keeps local before direct call barrier" {
  // Binaryen version_130 keeps even a pure const carrier before a direct call to
  // a locally-defined no-arg/no-side-effect callee. This is a refreshed
  // calls/nonthrowing-call precision boundary, not a red-first Starshine gap.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $callee (result i32) i32.const 99) (func (result i32) (local i32) i32.const 7 local.set 0 call $callee drop local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure direct-call barrier success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure sinks ref.as_non_null across read-only load" {
  // Binaryen version_130 sinks a nullable-local ref.as_non_null carrier across a
  // dropped read-only dynamic load. This covers the null-trap ordering positive
  // without using nondefaultable locals, which remain a separate fixup row.
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (param externref i32) (result (ref extern)) (local externref) local.get 0 ref.as_non_null local.set 2 local.get 1 i32.load drop local.get 2 ref.as_non_null))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure ref.as_non_null sink success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("ref.as_non_null"), msg=pretty)
  assert_true(pretty.contains("load"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
}

///|
test "simplify-locals-nostructure canonicalizes no-normal try_table result" {
  // Binaryen version_130 removes the result annotation from a try_table whose
  // body cannot produce a normal value, then leaves explicit unreachable debris
  // when the enclosing result-typed context still needs stack polymorphism. This
  // is the reduced 1000-lane EH size-losing residual family.
  let optimized = match
    pass_test_run_pipeline(
      "(module (tag $e) (elem declare func $dummy) (func $dummy) (func (local funcref) ref.func $dummy local.set 0 local.get 0 drop (drop (block $h (result exnref) (try_table (result exnref) (catch_ref $e $h) unreachable)))))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure no-normal try_table success, got \{err}",
      )
  }

  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "simplify-locals-nostructure canonicalizes no-normal if-arm try_table result" {
  // Binaryen version_130 also removes the result annotation when the no-normal
  // try_table is the non-fallthrough arm of a result-typed if feeding an outer
  // value context. The arm must leave explicit unreachable so the if remains
  // stack-polymorphic and the opposite arm can provide the result.
  let optimized = match
    pass_test_run_pipeline(
      "(module (tag $e) (global $g (mut exnref) ref.null noexn) (elem declare func $dummy) (func $dummy) (func $use (param exnref)) (func (local funcref) ref.func $dummy local.set 0 local.get 0 drop (call $use (block $h (result exnref) (if (result exnref) (i32.const 0) (then (try_table (result exnref) (catch_ref $e $h) throw $e)) (else global.get $g))))))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure no-normal if-arm try_table success, got \{err}",
      )
  }

  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(2U)),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "simplify-locals-nostructure keeps dead else catch_ref if without local refinalization trigger" {
  // Partial 10000 residual case-001895 exposed this direction: Binaryen
  // version_130 does not void a dead `else` catch_ref try_table without a
  // same-function ref.func local simplification trigger. The no-normal
  // tag-payload if-arm cleanup must stay tied to that trigger.
  let optimized = match
    pass_test_run_pipeline(
      "(module (type $t (func (param i31ref exnref) (result externref))) (import \"env\" \"f\" (func $f (type $t))) (tag $e) (func $use (param i31ref exnref) (result externref) local.get 0 (block $h (result exnref) i32.const 1 (if (result exnref) (then ref.null exn) (else (try_table (result exnref) (catch_ref $e $h) throw $e)))) call $f drop ref.null extern))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure dead else catch_ref success, got \{err}",
      )
  }

  assert_true(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
}

///|
test "simplify-locals-nostructure keeps dead else catch_ref if only local cleanup happens" {
  // Fresh reduction of partial 10000 residual case-001895. Binaryen
  // version_130 still keeps the constant-dead `else` catch_ref try_table
  // result-typed when the function merely performs ordinary local cleanup; a
  // broad dead-arm catch_ref canonicalizer over-voided this shape in Starshine.
  let optimized = match
    pass_test_run_pipeline(
      "(module (type $t (func (param i31ref exnref) (result externref))) (import \"env\" \"f\" (func $f (type $t))) (tag $e) (func $use (param i31ref exnref) (result externref) (local i32) i32.const 50 local.set 2 local.get 2 drop local.get 0 (block $h (result exnref) i32.const 1 (if (result exnref) (then ref.null exn) (else (try_table (result exnref) (catch_ref $e $h) throw $e)))) call $f drop ref.null extern))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure local-cleanup dead else catch_ref success, got \{err}",
      )
  }

  assert_true(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
}

///|
test "simplify-locals-nostructure keeps dead else catch_ref if only later direct call_ref is refinalized" {
  // Direct-lib reduction of partial 10000 residual case-001895. The WAT parser
  // path is blocked on the generated call_ref spelling, so build the small
  // module directly: a dead `else` catch_ref try_table feeds an imported call,
  // and a later block/ref.func/call_ref causes Starshine-only refinalization.
  // Binaryen version_130 keeps the catch_ref try_table result-typed here.
  let trace : Array[String] = []
  let callee_type = @lib.TypeIdx::new(0U)
  let use_type = @lib.TypeIdx::new(1U)
  let import_func = @lib.FuncIdx::new(0U)
  let dummy_func = @lib.FuncIdx::new(1U)
  let tag_idx = @lib.TagIdx::new(0U)
  let exnref_block = @lib.BlockType::val_type(@lib.ValType::ref_null_exn())
  let nullable_callee_block = @lib.BlockType::val_type(
    @lib.ValType::ref_type(
      @lib.RefType::new(true, @lib.HeapType::new(callee_type)),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::i31ref(), @lib.ValType::ref_null_exn()],
              [
                @lib.ValType::ref_null(
                  @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
                ),
              ],
            ),
          ),
        ),
      ]),
    )
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("f"),
          @lib.ExternType::func(use_type),
        ),
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(callee_type)]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([dummy_func]),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([callee_type, use_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::block(
              exnref_block,
              @lib.Expr::new([
                @lib.Instruction::i32_const(@lib.I32(1)),
                @lib.Instruction::if_(
                  exnref_block,
                  [
                    @lib.Instruction::ref_null(
                      @lib.HeapType::abs(@lib.AbsHeapType::exn()),
                    ),
                  ],
                  Some([
                    @lib.Instruction::try_table(
                      exnref_block,
                      [@lib.Catch::ref_(tag_idx, @lib.LabelIdx::new(0U))],
                      @lib.Expr::new([@lib.Instruction::throw_(tag_idx)]),
                    ),
                  ]),
                ),
              ]),
            ),
            @lib.Instruction::call(import_func),
            @lib.Instruction::drop(),
            @lib.Instruction::block(
              nullable_callee_block,
              @lib.Expr::new([@lib.Instruction::ref_func(dummy_func)]),
            ),
            @lib.Instruction::call_ref(callee_type),
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure dead else direct-call_ref success, got \{err}",
      )
  }
  let trace_text = "\{trace}"
  assert_false(trace_text.contains("skip-invalid-lower"), msg=trace_text)
  assert_true(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
}

///|
test "simplify-locals-nostructure canonicalizes live const-then catch_ref if after refinalization trigger" {
  // Partial 10000 residual case-005987 is the catch_ref sibling of the
  // refinalization-triggered live single-arm catch_all_ref bucket: Binaryen
  // version_130 voids the live no-normal catch_ref try_table when the opposite
  // constant-dead arm supplies the result and the same function also simplifies
  // a ref.func local set/get pair.
  let optimized = match
    pass_test_run_pipeline(
      "(module (elem declare func $dummy) (tag $e) (func $dummy) (func (result exnref) (local funcref) ref.func $dummy local.set 0 local.get 0 drop (block $h (result exnref) (if (result exnref) (i32.const 1) (then (try_table (result exnref) (catch_ref $e $h) throw $e)) (else ref.null exn)))))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure refinalized live const-then catch_ref success, got \{err}",
      )
  }

  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
}

///|
test "simplify-locals-nostructure canonicalizes live const-then catch_all_ref if after refinalization trigger" {
  // Fresh partial 10000 residual case-001740 shows a single live `then` arm
  // with a no-normal catch_all_ref try_table under a constant condition.
  // Binaryen version_130 voids that live try_table only in a same-function
  // ref.func local simplification / ReFinalize context while the opposite arm
  // supplies the fallthrough result type.
  let optimized = match
    pass_test_run_pipeline(
      "(module (elem declare func $dummy) (tag $e) (func $dummy) (func (result exnref) (local funcref) ref.func $dummy local.set 0 local.get 0 drop (block $h (result exnref) (if (result exnref) (i32.const 1) (then (try_table (result exnref) (catch_all_ref $h) throw $e)) (else ref.null exn)))))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure refinalized live const-then catch_all_ref success, got \{err}",
      )
  }

  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
}

///|
test "simplify-locals-nostructure keeps both-arm catch_all_ref if without refinalization trigger" {
  // Binaryen version_130 keeps both arms result-typed when no same-function
  // local simplification asks ReFinalize. This guards against broad
  // catch_all_ref if-arm rewriting while fixing the case-000251 direction.
  let optimized = match
    pass_test_run_pipeline(
      "(module (tag $e) (func (result exnref) (block $h (result exnref) (if (result exnref) (i32.const 0) (then (try_table (result exnref) (catch_all_ref $h) throw $e)) (else (try_table (result exnref) (catch_all_ref $h) throw $e))))))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure both-arm catch_all_ref boundary success, got \{err}",
      )
  }

  assert_true(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(0U)),
  )
}

///|
test "simplify-locals-nostructure canonicalizes both-arm catch_all_ref if after refinalization trigger" {
  // The remaining post-refinalized-live-catchall2 non-annotation residual,
  // case-000251, has both arms as no-normal catch_all_ref try_tables. Binaryen
  // version_130 voids those try_tables only when a same-function ref.func
  // set/get simplification triggers ReFinalize.
  let optimized = match
    pass_test_run_pipeline(
      "(module (elem declare func $dummy) (tag $e) (func $dummy) (func (result exnref) (local funcref) ref.func $dummy local.set 0 local.get 0 drop (block $h (result exnref) (if (result exnref) (i32.const 0) (then (try_table (result exnref) (catch_all_ref $h) throw $e)) (else (try_table (result exnref) (catch_all_ref $h) throw $e))))))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure refinalized both-arm catch_all_ref success, got \{err}",
      )
  }

  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
}

///|
test "simplify-locals-nostructure canonicalizes mixed catch_all_ref catch_ref if after refinalization trigger" {
  // Partial 10000 residual case-007981 has a generated call_ref operand block
  // whose constant-condition if has both no-normal EH arms: catch_all_ref in
  // one arm and catch_ref in the other. Binaryen version_130 voids both arms
  // after a same-function ref.func local simplification triggers ReFinalize.
  // This public fixture avoids the generated call_ref spelling while preserving
  // the imported-call operand and mixed EH arm shape.
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (type $ft (func)) (import \"env\" \"f\" (func $f (param f64 exnref))) (elem declare func $dummy) (tag $e) (func $dummy (type $ft)) (func (local funcref) ref.func $dummy local.set 0 local.get 0 drop (call $f (f64.const 1) (block $h (result exnref) (if (result exnref) (i32.const 0) (then (try_table (result exnref) (catch_all_ref $h) throw $e)) (else (try_table (result exnref) (catch_ref $e $h) throw $e)))))))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure refinalized mixed EH arms success, got \{err}",
      )
  }

  let trace_text = "\{trace}"
  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg="\{optimized.pretty_print_func(@lib.FuncIdx::new(2U))}\ntrace=\{trace_text}",
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "simplify-locals-nostructure canonicalizes reverse mixed catch_ref catch_all_ref if after refinalization trigger" {
  // Partial 10000 residual case-009315 is the reverse-arm sibling of
  // case-007981: the constant-dead then arm catches with `catch_ref`, while
  // the live else arm catches with `catch_all_ref`. Binaryen version_130 wraps
  // the operand if in a non-null exn block, voids the if, and leaves explicit
  // unreachable debris after same-function ref.func local cleanup triggers
  // ReFinalize. The initial reduced probe kept a nullable/result-typed wrapper.
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      "(module (type $ft (func)) (import \"env\" \"f\" (func $f (param exnref anyref) (result i31ref))) (elem declare func $dummy) (tag $e) (func $dummy (type $ft)) (func (param anyref) (result i31ref) (local funcref) ref.func $dummy local.set 1 local.get 1 drop (call $f (block $h (result exnref) (if (result exnref) (i32.const 0) (then (try_table (result exnref) (catch_ref $e $h) throw $e)) (else (try_table (result exnref) (catch_all_ref $h) throw $e)))) (local.get 0))))",
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure reverse mixed EH arms success, got \{err}",
      )
  }

  let trace_text = "\{trace}"
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg="\{pretty}\ntrace=\{trace_text}",
  )
  assert_false(
    pretty.contains("if (RefType"),
    msg="expected Binaryen-shaped void if after EH canonicalization\n\{pretty}\ntrace=\{trace_text}",
  )
  assert_false(
    pretty.contains("block (RefType Null (HeapType (AbsHeapType Exn)))"),
    msg="expected non-null exn wrapper after EH canonicalization\n\{pretty}\ntrace=\{trace_text}",
  )
}

///|
test "simplify-locals-nostructure keeps exact table-set if validating while directizing later call_ref local" {
  // Generated case-000251 combines a `funcref` if that feeds `table.set`, a
  // later `ref.func; local.set; local.get; call_ref` wrapper, and the
  // catch_all_ref refinalization trigger. Starshine must rewrite the
  // `ref.null func` arm when narrowing the if result to an exact func type so
  // the exact table-set value validates instead of rolling back the whole
  // lowered cleanup. Use the direct-lib fixture because the public WAT path is
  // still parser-blocked for the required generated `call_ref` spelling.
  let trace : Array[String] = []
  let func_type = @lib.TypeIdx::new(0U)
  let run_type = @lib.TypeIdx::new(1U)
  let callee_idx = @lib.FuncIdx::new(0U)
  let target_local = @lib.LocalIdx::new(1U)
  let tag_idx = @lib.TagIdx::new(0U)
  let imported_table = @lib.TableIdx::new(0U)
  let funcref_block = @lib.BlockType::val_type(@lib.ValType::funcref())
  let exnref_block = @lib.BlockType::val_type(@lib.ValType::ref_null_exn())
  let no_normal_try = fn() {
    @lib.Instruction::try_table(
      exnref_block,
      [@lib.Catch::all_ref(@lib.LabelIdx::new(0U))],
      @lib.Expr::new([@lib.Instruction::throw_(tag_idx)]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::ref_null_exn()]),
          ),
        ),
      ]),
    )
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("imported_table_0"),
          @lib.ExternType::table(
            @lib.TableType::new(
              @lib.RefType::new(
                true,
                @lib.HeapType::abs(@lib.AbsHeapType::func()),
              ),
              @lib.Limits::i32(1U, Some(3U)),
            ),
          ),
        ),
      ]),
    )
    .with_tag_sec(@lib.TagSec::new([@lib.TagType::new(func_type)]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([callee_idx]),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type, run_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::from_types([
            @lib.ValType::i32(),
            @lib.ValType::ref_type(
              @lib.RefType::new(true, @lib.HeapType::new(func_type)),
            ),
          ]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::if_(
              funcref_block,
              [@lib.Instruction::ref_func(callee_idx)],
              Some([
                @lib.Instruction::ref_null(
                  @lib.HeapType::abs(@lib.AbsHeapType::func()),
                ),
              ]),
            ),
            @lib.Instruction::table_set(imported_table),
            @lib.Instruction::ref_func(callee_idx),
            @lib.Instruction::local_set(target_local),
            @lib.Instruction::local_get(target_local),
            @lib.Instruction::call_ref(func_type),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::if_(
              exnref_block,
              [no_normal_try()],
              Some([no_normal_try()]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure table-set/refinalization success, got \{err}",
      )
  }
  let trace_text = "\{trace}"
  assert_false(trace_text.contains("skip-invalid-lower"), msg=trace_text)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("Exact (HeapType Idx 0)"), msg=pretty)
  assert_true(
    pretty.contains("ref.null (RefType Null Exact (HeapType Idx 0))"),
    msg=pretty,
  )
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_true(pretty.contains("call_ref"), msg=pretty)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected exact table-set/call_ref cleanup to validate, got \{@validate.validation_error_message(err)}: \{pretty}",
      )
  }
}

///|
test "simplify-locals-nostructure refinalizes table-set if after direct call_ref local" {
  // Partial 10000 residual case-008144 shows that Binaryen version_130 narrows
  // an earlier `funcref` if feeding `table.set` after a same-function
  // `ref.func; local.set; local.get; call_ref` cleanup, even without the EH
  // catch_all_ref trigger covered by case-000251. Keep this direct-lib fixture
  // because the public WAT path is still parser-blocked for the generated
  // call_ref spelling used by the reducer.
  let trace : Array[String] = []
  let func_type = @lib.TypeIdx::new(0U)
  let import_type = @lib.TypeIdx::new(1U)
  let run_type = @lib.TypeIdx::new(0U)
  let callee_idx = @lib.FuncIdx::new(1U)
  let table_idx = @lib.TableIdx::new(0U)
  let target_local = @lib.LocalIdx::new(1U)
  let funcref_block = @lib.BlockType::val_type(@lib.ValType::funcref())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::eqref_null()]),
          ),
        ),
      ]),
    )
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("imported_func_0"),
          @lib.ExternType::func(import_type),
        ),
      ]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::new(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Limits::i32(1U, Some(3U)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([callee_idx]),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type, run_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::from_types([
            @lib.ValType::i32(),
            @lib.ValType::ref_type(
              @lib.RefType::new(true, @lib.HeapType::new(func_type)),
            ),
          ]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::if_(
              funcref_block,
              [@lib.Instruction::ref_func(callee_idx)],
              Some([
                @lib.Instruction::ref_null(
                  @lib.HeapType::abs(@lib.AbsHeapType::func()),
                ),
              ]),
            ),
            @lib.Instruction::table_set(table_idx),
            @lib.Instruction::ref_func(callee_idx),
            @lib.Instruction::local_set(target_local),
            @lib.Instruction::local_get(target_local),
            @lib.Instruction::call_ref(func_type),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure non-EH table-set/refinalization success, got \{err}",
      )
  }
  let trace_text = "\{trace}"
  assert_false(trace_text.contains("skip-invalid-lower"), msg=trace_text)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("Exact (HeapType Idx 0)"), msg=pretty)
  assert_true(
    pretty.contains("ref.null (RefType Null Exact (HeapType Idx 0))"),
    msg=pretty,
  )
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_true(pretty.contains("call_ref"), msg=pretty)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected non-EH exact table-set/call_ref cleanup to validate, got \{@validate.validation_error_message(err)}: \{pretty}",
      )
  }
}

///|
test "simplify-locals-nostructure refinalizes table-set if across intervening imported call" {
  // Fresh case-008144 still has a non-annotation residual after the simpler
  // non-EH table-set/call_ref local fixture was fixed: Binaryen version_130
  // narrows the earlier funcref if feeding table.set even when both arms are
  // wrapped in transparent funcref blocks and an imported call sits between
  // that table write and the later ref.func local set/get/call_ref cleanup.
  // Keep this direct-lib reduction because public call_ref WAT remains
  // parser-blocked for the generated spelling.
  let trace : Array[String] = []
  let func_type = @lib.TypeIdx::new(0U)
  let import_type = @lib.TypeIdx::new(1U)
  let run_type = @lib.TypeIdx::new(0U)
  let import_func = @lib.FuncIdx::new(0U)
  let callee_idx = @lib.FuncIdx::new(1U)
  let table_idx = @lib.TableIdx::new(0U)
  let target_local = @lib.LocalIdx::new(1U)
  let funcref_block = @lib.BlockType::val_type(@lib.ValType::funcref())
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::eqref_null()]),
          ),
        ),
      ]),
    )
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("env"),
          @lib.Name::from_string("imported_func_0"),
          @lib.ExternType::func(import_type),
        ),
      ]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(
            @lib.RefType::new(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::func()),
            ),
            @lib.Limits::i32(1U, Some(3U)),
          ),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([callee_idx]),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type, run_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::from_types([
            @lib.ValType::i32(),
            @lib.ValType::ref_type(
              @lib.RefType::new(true, @lib.HeapType::new(func_type)),
            ),
          ]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::if_(
              funcref_block,
              [
                @lib.Instruction::block(
                  funcref_block,
                  @lib.Expr::new([
                    @lib.Instruction::block(
                      funcref_block,
                      @lib.Expr::new([@lib.Instruction::ref_func(callee_idx)]),
                    ),
                  ]),
                ),
              ],
              Some([
                @lib.Instruction::block(
                  funcref_block,
                  @lib.Expr::new([
                    @lib.Instruction::ref_null(
                      @lib.HeapType::abs(@lib.AbsHeapType::func()),
                    ),
                  ]),
                ),
              ]),
            ),
            @lib.Instruction::table_set(table_idx),
            @lib.Instruction::call(import_func),
            @lib.Instruction::drop(),
            @lib.Instruction::ref_func(callee_idx),
            @lib.Instruction::local_set(target_local),
            @lib.Instruction::local_get(target_local),
            @lib.Instruction::call_ref(func_type),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure intervening-call table-set/refinalization success, got \{err}",
      )
  }
  let trace_text = "\{trace}"
  assert_false(trace_text.contains("skip-invalid-lower"), msg=trace_text)
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("Exact (HeapType Idx 0)"), msg=pretty)
  assert_true(
    pretty.contains("ref.null (RefType Null Exact (HeapType Idx 0))"),
    msg=pretty,
  )
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_true(pretty.contains("call_ref"), msg=pretty)
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected intervening-call exact table-set/call_ref cleanup to validate, got \{@validate.validation_error_message(err)}: \{pretty}",
      )
  }
}

///|
test "simplify-locals-nostructure keeps live no-normal catch_all_ref block without refinalization trigger" {
  // Binaryen version_130 keeps this live call-argument block result-typed when
  // the same function has no local simplification that asks Binaryen to
  // ReFinalize. This is the case-000305 boundary that rejected broad live-block
  // rewriting.
  let optimized = match
    pass_test_run_pipeline(
      "(module (import \"env\" \"f\" (func $f (param exnref i64))) (func (block $h (result exnref) (try_table (result exnref) (catch_all_ref $h) unreachable)) i64.const 0 call $f))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure live catch_all_ref boundary success, got \{err}",
      )
  }

  assert_true(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
}

///|
test "simplify-locals-nostructure canonicalizes live no-normal catch_all_ref block after refinalization trigger" {
  // Adding only a same-function ref.func local set/get pair makes Binaryen
  // version_130 simplify that local traffic and then ReFinalize the live
  // call-argument block to a void try_table plus explicit unreachable. This is
  // the narrowed case-000692 direction; it must not become a general live-block
  // rewrite.
  let optimized = match
    pass_test_run_pipeline(
      "(module (import \"env\" \"f\" (func $f (param exnref i64))) (elem declare func $dummy) (func $dummy) (func (local funcref) ref.func $dummy local.set 0 local.get 0 drop (block $h (result exnref) (try_table (result exnref) (catch_all_ref $h) unreachable)) i64.const 0 call $f))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure refinalized live catch_all_ref success, got \{err}",
      )
  }

  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(2U)),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "simplify-locals-nostructure canonicalizes refinalized tail catch_all_ref block" {
  // Partial 10000 residual case-004556 shows the same Binaryen ReFinalize
  // discriminator as case-000692, but with prefix statements before a tail
  // no-normal catch_all_ref try_table inside the result block. Binaryen
  // version_130 voids the tail try_table and narrows the block under the
  // same-function ref.func local simplification trigger.
  let optimized = match
    pass_test_run_pipeline(
      "(module (elem declare func $dummy) (tag $e) (func $dummy) (func (result exnref) (local funcref) ref.func $dummy local.set 0 local.get 0 drop (block $h (result exnref) nop (try_table (result exnref) (catch_all_ref $h) throw $e))))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure refinalized tail catch_all_ref success, got \{err}",
      )
  }

  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
}

///|
test "simplify-locals-nostructure canonicalizes refinalized function-tail catch_all_ref" {
  // Partial 10000 residuals case-004933, case-007606, and case-007797 are
  // generated function-tail catch_all_ref siblings of the function-tail
  // catch_ref case-005508: Binaryen version_130 wraps the function result in a
  // non-null exn block, voids the no-normal tail try_table, and leaves explicit
  // unreachable only under the same-function ref.func local simplification /
  // ReFinalize discriminator.
  let optimized = match
    pass_test_run_pipeline(
      "(module (elem declare func $dummy) (tag $e) (func $dummy) (func (result exnref) (local funcref) ref.func $dummy local.set 0 local.get 0 drop nop (try_table (result exnref) (catch_all_ref 0) throw $e)))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure refinalized function-tail catch_all_ref success, got \{err}",
      )
  }

  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
}

///|
test "simplify-locals-nostructure canonicalizes refinalized function-tail catch_ref" {
  // Partial 10000 residual case-005508 is the catch_ref sibling of the
  // function-tail catch_all_ref bucket: Binaryen version_130 wraps the
  // function result in a non-null exn block and voids the no-normal tail
  // try_table only under the same-function ref.func local simplification
  // / ReFinalize discriminator.
  let optimized = match
    pass_test_run_pipeline(
      "(module (elem declare func $dummy) (tag $e) (func $dummy) (func (result exnref) (local funcref) ref.func $dummy local.set 0 local.get 0 drop nop (try_table (result exnref) (catch_ref $e 0) throw $e)))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure refinalized function-tail catch_ref success, got \{err}",
      )
  }

  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
}

///|
test "simplify-locals-nostructure canonicalizes dead then catch_all_ref if after refinalization trigger" {
  // Partial 10000 residual case-009494 has the catch_all_ref try_table in the
  // constant-dead then arm of an imported-call operand block, with the opposite
  // arm supplying `ref.null exn`. Binaryen version_130 still voids that
  // no-normal arm after a same-function ref.func local simplification triggers
  // ReFinalize. This public fixture avoids the generated call_ref spelling that
  // remains parser-blocked in the full residual.
  let optimized = match
    pass_test_run_pipeline(
      "(module (type $ft (func)) (import \"env\" \"f\" (func $f (param i31ref exnref))) (elem declare func $dummy) (tag $e) (func $dummy (type $ft)) (func (local funcref) ref.func $dummy local.set 0 local.get 0 drop (call $f (ref.null i31) (block $h (result exnref) (if (result exnref) (i32.const 0) (then (try_table (result exnref) (catch_all_ref $h) throw $e)) (else ref.null exn))))))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure refinalized dead-then catch_all_ref success, got \{err}",
      )
  }

  assert_false(
    slns_test_module_has_nonvoid_no_normal_try_table(optimized),
    msg=optimized.pretty_print_func(@lib.FuncIdx::new(2U)),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "simplify-locals-nostructure keeps throwing set before try_table body" {
  // Calls may throw, so Binaryen drops the pending sinkable before entering
  // the try_table. Sinking this call into the body could make the handler catch
  // an exception that was previously outside the handler.
  let optimized = match
    pass_test_run_pipeline(
      "(module (import \"env\" \"maybe\" (func $maybe (result i32))) (tag $e (param i32)) (func (result i32) (local i32) call $maybe local.set 0 (block $h (result i32) (try_table (result i32) (catch $e $h) local.get 0))))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure throwing try_table barrier success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure optimizes unrelated locals when an existing tee is present" {
  // `notee` disables creating new tees, but Binaryen version_130 still cleans
  // existing dropped tees and sinks unrelated single-use local traffic.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32 i32) i32.const 1 local.tee 0 drop i32.const 7 local.set 1 local.get 1))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-notee-nostructure existing-tee success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("local.tee"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
fn simplify_locals_nostructure_test_large_module() -> String {
  let out = StringBuilder::new()
  out.write_string("(module\n")
  let mut idx = 0
  while idx < 101 {
    out.write_string("  (func $f")
    out.write_string(idx.to_string())
    out.write_string(" (result i32) (local i32) i32.const ")
    out.write_string((idx & 1).to_string())
    out.write_string(" local.set 0 local.get 0)\n")
    idx += 1
  }
  out.write_string(")")
  out.to_string()
}

///|
test "simplify-locals-notee-nostructure runs safe large modules" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      simplify_locals_nostructure_test_large_module(),
      ["simplify-locals-notee-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-notee-nostructure large module success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains("pass[simplify-locals-notee-nostructure]:skip-large-module")
    }),
    msg=trace.to_string(),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(100U))
  assert_true(pretty.contains("I32(0)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure folds dead exact-slot set-copy local" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) (local.set 2 (block $block (result i32) (if (local.get 0) (then (i32.const 7) (br $block))) (i32.const 9))) (local.set 1 (local.get 2)) (i32.add (local.get 1) (local.get 1))))",
      ["simplify-locals-nostructure", "reorder-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure set-copy fold success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("Local 1"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
}

///|
test "simplify-locals-nostructure folds exact-slot set-copy across cleanup nop" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32 i32) loop $l block $block (result i32) (if (local.get 0) (then (return (i32.const 0)))) (i32.const 9) end local.set 2 nop local.get 2 local.set 1 (br_if $l (local.get 0)) end (i32.add (local.get 1) (local.get 1))))",
      ["simplify-locals-nostructure", "vacuum", "reorder-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure nop-separated set-copy fold success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("Local 1"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 2)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 2)"), msg=pretty)
}

///|
test "simplify-locals-nostructure keeps tee before dependent loads" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (param i32) (result i32) (local i32 i32 i32 i32 i32 i32) local.get 0 local.tee 5 i32.load offset=20 align=1 local.get 5 i32.load offset=12 align=1 local.get 5 i32.load offset=16 align=1 local.set 4 local.set 3 local.set 2 local.get 2 local.get 3 local.get 4 i32.add i32.add))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure dependent-load success, got \{err}",
      )
  }

  let instrs = match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs.get(0) {
        Some(@lib.Func(_, @lib.Expr(instrs))) => instrs
        None => fail("expected first function body")
      }
    None => fail("expected code section")
  }
  match instrs[0] {
    @lib.LocalGet(@lib.LocalIdx(local_id)) => @debug.assert_eq(local_id, 0U)
    _ => fail("expected source pointer local.get to remain first")
  }
  match instrs[1] {
    @lib.LocalTee(@lib.LocalIdx(local_id)) => @debug.assert_eq(local_id, 5U)
    _ => fail("expected dependent-load local.tee to remain before loads")
  }
}

///|
test "simplify-locals-nostructure preserves used condition load tee" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func $incref (param i32)) (func $decref (param i32)) (func $free (param i32)) (func (param $io i32) (result i32) (local $field i32)" +
      simplify_locals_nostructure_test_many_i32_locals(110) +
      " (local $cnt i32) (block $block (if (i32.const 0) (then (return (i32.const 0))) (else (br $block))) (unreachable)) (local.set $field (i32.load offset=32 align=1 (local.get $io))) (if (i32.gt_s (local.tee $cnt (i32.load align=1 (local.get $io))) (i32.const 1)) (then nop (i32.store align=1 (local.get $io) (i32.sub (local.get $cnt) (i32.const 1))) (call $incref (local.get $field))) (else (if (i32.eq (local.get $cnt) (i32.const 1)) (then (call $decref (i32.load offset=40 align=1 (local.get $io))) (call $free (local.get $io)))))) (call $decref (local.get $field)) (i32.const 1)))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure condition tee preservation success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 112)"), msg=pretty)
}

///|
test "simplify-locals-nostructure creates tees for later-cycle multi-use locals" {
  // Binaryen version_130's first cycle refuses multi-use tee creation, then the
  // forced later cycle sinks the value through a fresh tee. This is the
  // tee-enabled half of the no-structure template identity.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 7 local.set 0 local.get 0 local.get 0 i32.add))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals-nostructure tee success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.tee (Local 0)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure avoids tees when the first use is dropped" {
  // A dropped first use can be cleaned without a tee; Binaryen version_130 emits
  // only the final constant carrier after replacing the drop(get) pair.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 7 local.set 0 local.get 0 drop local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure dropped-first-use success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("local.tee (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure does not create tees for multi-use locals" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 i32.const 7 i32.add local.set 1 local.get 1 local.get 1 i32.add))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals-notee-nostructure success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.tee (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-notee-nostructure preserves Binaryen const-nop loop shape" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result f64) loop (result f64) f64.const 1.0 nop end))",
      ["simplify-locals-notee-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected simplify-locals-notee-nostructure success, got \{err}")
  }

  match optimized.code_sec {
    Some(
      @lib.CodeSec(
        [@lib.Func(locals, @lib.Expr([@lib.Loop(_, @lib.Expr(body))]))]
      )
    ) => {
      @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::f64()]))
      @debug.assert_eq(body.length(), 3)
      @debug.assert_eq(body[0], @lib.Instruction::nop())
      @debug.assert_eq(body[1], @lib.Instruction::nop())
      match body[2] {
        @lib.F64Const(_) => ()
        other => fail("expected trailing f64 const after nops, got \{other}")
      }
    }
    other =>
      fail(
        "expected one loop body after no-tee no-structure pass, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "simplify-locals-nostructure canonicalizes late equivalent gets" {
  // Binaryen version_130 keeps the no-structure late equivalent-local phase:
  // it rewrites both uses of the copied local back to the original param and
  // the final dead-set cleanup removes the now-unused copy set.
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (param i32) (result f32) (local i32) local.get 0 local.set 1 local.get 1 i32.const 1 i32.store local.get 1 f32.load))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure equivalent-get success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("store"), msg=pretty)
  assert_true(pretty.contains("load"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-nostructure does not synthesize if results" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 1 local.set 1 else i32.const 2 local.set 1 end local.get 1))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals-nostructure success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("if I32"), msg=pretty)
  assert_true(pretty.contains("if (Void)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-nostructure sinks across fallthrough block without block result" {
  // Binaryen version_130 sinks this simple fallthrough block carrier but keeps
  // the block itself void; this is not the disabled structure-synthesis family.
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) block i32.const 7 local.set 0 end local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure fallthrough-block success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("block (Void)"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("block I32"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_false(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure does not synthesize loop results" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) loop i32.const 7 local.set 0 end local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure loop-no-structure success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("loop I32"), msg=pretty)
  assert_true(pretty.contains("loop (Void)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure does not synthesize one-armed if results" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 7 local.set 1 end local.get 1))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure one-armed-if success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("if I32"), msg=pretty)
  assert_true(pretty.contains("if (Void)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "simplify-locals-nostructure does not synthesize branch-created block results" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) block $b i32.const 7 local.set 0 br $b end local.get 0))",
      ["simplify-locals-nostructure"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure branch-block success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("block I32"), msg=pretty)
  assert_true(pretty.contains("block (Void)"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 0)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
}

///|
test "simplify-locals-nostructure can clean tuple-carried locals through its helper lane" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) (local i32 i32 i32) block (result i32 i32 i32) i32.const 10 i32.const 20 i32.const 30 end local.set 2 local.set 1 local.set 0 local.get 0))",
  )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(),
      simplify_locals_nostructure_exact_slot_passes(),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure helper-lane cleanup success, got \{err}",
      )
  }

  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected helper-lane cleanup module to validate, got \{err}")
  }

  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(locals, _)])) =>
      @debug.assert_eq(locals, @lib.Locals::empty())
    other =>
      fail(
        "expected exact slot replay single-function output, got \{@debug.to_string(other)}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(10)"), msg=pretty)
  assert_false(pretty.contains("local.set"), msg=pretty)
  assert_false(pretty.contains("local.get"), msg=pretty)
}

///|
test "simplify-locals-nostructure keeps the no-structure if boundary through its helper lane" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) (local i32) local.get 0 if i32.const 1 local.set 1 else i32.const 2 local.set 1 end local.get 1))",
  )
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(),
      simplify_locals_nostructure_exact_slot_passes(),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected simplify-locals-nostructure helper-lane no-structure success, got \{err}",
      )
  }

  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail("expected helper-lane no-structure module to validate, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("if I32"), msg=pretty)
  assert_true(pretty.contains("if (Void)"), msg=pretty)
}

///|
fn simplify_locals_nostructure_giant_post_inline_call_builder(
  call_count : Int,
) -> String {
  let source = StringBuilder::new()
  source.write_string(
    "(module (func $id (param i32) (result i32) local.get 0) (func (export \"run\") (local i32 i32 i32 i32 i32 i32 i32) i32.const 0 local.set 1 i32.const 0 local.set 2 i32.const 0 local.set 3 i32.const 0 local.set 4 i32.const 0 local.set 5 i32.const 0 local.set 6 (block ",
  )
  for i = 0; i < call_count; i = i + 1 {
    source.write_string("local.get 0 call $id drop ")
  }
  source.write_string(")))")
  source.to_string()
}

///|
test "simplify-locals-nostructure bounds giant post-inline call builders" {
  let source = simplify_locals_nostructure_giant_post_inline_call_builder(1400)
  for pass_name in ["simplify-locals-nostructure", "simplify-locals"] {
    let trace = match pass_test_capture_trace(source, [pass_name]) {
      Ok(trace) => trace
      Err(err) =>
        fail("expected bounded giant call builder \{pass_name}, got \{err}")
    }
    assert_true(
      trace.any(fn(line) {
        line.contains("reason=giant-post-inline-call-builder")
      }),
      msg=trace.to_string(),
    )
  }
}

///|
test "simplify-locals bounds loop-carried local writes" {
  let source =
    #|(module
    #|  (import "env" "sink" (func $sink (param i32)))
    #|  (func (param $limit i32) (result i32) (local $i i32)
    #|    i32.const 0
    #|    local.set $i
    #|    loop
    #|      local.get $i
    #|      i32.const 1
    #|      i32.add
    #|      local.set $i
    #|      local.get $i
    #|      call $sink
    #|      local.get $i
    #|      local.get $limit
    #|      i32.lt_s
    #|      br_if 0
    #|    end
    #|    local.get $i))
    #|
  for pass_name in ["simplify-locals-nostructure", "simplify-locals"] {
    let trace = match pass_test_capture_trace(source, [pass_name]) {
      Ok(trace) => trace
      Err(err) =>
        fail("expected loop-carried local boundary \{pass_name}, got \{err}")
    }
    assert_true(
      trace.any(fn(line) { line.contains("reason=loop-carried-local-write") }),
      msg=trace.to_string(),
    )
  }
}

///|
test "simplify-locals bounds parameter-initialized loop carriers" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32) (local i32 i32 i32)
    #|    local.get 0
    #|    local.get 1
    #|    i32.add
    #|    local.set 2
    #|    local.get 0
    #|    local.set 3
    #|    local.get 1
    #|    local.set 4
    #|    loop
    #|      local.get 2
    #|      local.get 3
    #|      i32.gt_s
    #|      if
    #|        local.get 3
    #|        i32.const 1
    #|        i32.add
    #|        local.set 3
    #|        local.get 4
    #|        i32.const 1
    #|        i32.add
    #|        local.set 4
    #|        br 1
    #|      end
    #|    end
    #|    local.get 4))
  for pass_name in ["simplify-locals-nostructure", "simplify-locals"] {
    let trace = match pass_test_capture_trace(source, [pass_name]) {
      Ok(trace) => trace
      Err(err) =>
        fail(
          "expected parameter loop-carrier boundary \{pass_name}, got \{err}",
        )
    }
    assert_true(
      trace.any(fn(line) { line.contains("reason=loop-carried-local-write") }),
      msg=trace.to_string(),
    )
  }
}

///|
test "simplify-locals-nostructure preflights oversized lowered builders" {
  let source = simplify_locals_nostructure_giant_post_inline_call_builder(2200)
  for pass_name in ["simplify-locals-nostructure", "simplify-locals"] {
    let trace = match pass_test_capture_trace(source, [pass_name]) {
      Ok(trace) => trace
      Err(err) => fail("expected oversized preflight \{pass_name}, got \{err}")
    }
    assert_true(
      trace.any(fn(line) {
        line.contains("reason=oversized-lowered-simplify-locals-preflight")
      }),
      msg=trace.to_string(),
    )
  }
}

///|
test "simplify-locals-nostructure preserves local-alias multi-call lifetimes" {
  let input =
    #|(module
    #|  (func $use (param i32 i32))
    #|  (func $release (param i32))
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    local.set 1
    #|    local.get 1
    #|    i32.const 7
    #|    call $use
    #|    local.get 1
    #|    call $release))
  let original = pass_test_module_from_wat(input)
  for pass_name in ["simplify-locals-nostructure", "simplify-locals"] {
    let trace : Array[String] = []
    let optimized = match
      pass_test_run_pipeline(
        input,
        [pass_name],
        options=HotPipelineOptions::new(
          trace=Some(fn(line) { trace.push(line) }),
        ),
      ) {
      Ok(mod_) => mod_
      Err(err) => fail("expected local-alias lifetime success, got \{err}")
    }
    @debug.assert_eq(optimized, original)
    assert_true(
      trace.any(fn(line) {
        line.contains("reason=local-alias-multi-call-lifetime")
      }),
      msg=trace.to_string(),
    )
  }
}

///|
test "simplify-locals-nostructure preserves effect-bracketed multivalue call spills" {
  let source =
    #|(module
    #|  (type $tri (func (param i32 i32) (result i32 i32 i32)))
    #|  (type $show (func (param i32 i32 i32) (result i32)))
    #|  (import "m" "retain" (func $retain (param i32)))
    #|  (import "m" "tri" (func $tri (type $tri)))
    #|  (import "m" "release" (func $release (param i32)))
    #|  (import "m" "show" (func $show (type $show)))
    #|  (func (param i32) (result i32) (local i32 i32 i32)
    #|    local.get 0
    #|    call $retain
    #|    local.get 0
    #|    i32.const 0
    #|    call $tri
    #|    local.get 0
    #|    call $release
    #|    local.set 3
    #|    local.set 2
    #|    local.tee 1
    #|    local.get 2
    #|    local.get 3
    #|    call $show
    #|    local.get 1
    #|    call $release))
  let original = pass_test_module_from_wat(source)
  for pass_name in ["simplify-locals-nostructure", "simplify-locals"] {
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
      Err(err) => fail("expected effect-bracketed simplify success, got \{err}")
    }
    @debug.assert_eq(optimized, original)
    assert_true(
      trace.any(fn(line) {
        line.contains(
          "reason=effect-bracketed-multivalue-call-simplify-locals-noop",
        )
      }),
      msg=trace.to_string(),
    )
  }
}

///|
test "simplify-locals-nostructure preserves call-result structured lifetimes" {
  let input =
    #|(module
    #|  (func $make (result i32) i32.const 1)
    #|  (func $test (param i32) (result i32) local.get 0)
    #|  (func $release (param i32))
    #|  (func (local i32)
    #|    call $make
    #|    local.set 0
    #|    local.get 0
    #|    call $test
    #|    if
    #|      local.get 0
    #|      call $release
    #|    end))
  let original = pass_test_module_from_wat(input)
  for pass_name in ["simplify-locals-nostructure", "simplify-locals"] {
    let trace : Array[String] = []
    let optimized = match
      pass_test_run_pipeline(
        input,
        [pass_name],
        options=HotPipelineOptions::new(
          trace=Some(fn(line) { trace.push(line) }),
        ),
      ) {
      Ok(mod_) => mod_
      Err(err) => fail("expected structured lifetime success, got \{err}")
    }
    @debug.assert_eq(optimized, original)
    assert_true(
      trace.any(fn(line) {
        line.contains("reason=call-result-structured-lifetime")
      }),
      msg=trace.to_string(),
    )
  }
}

///|
test "simplify-locals variants preserve call-result multi-call lifetimes" {
  let input =
    #|(module
    #|  (func $make (result i32) i32.const 1)
    #|  (func $use (param i32 i32))
    #|  (func $release (param i32))
    #|  (func (param i32) (local i32)
    #|    call $make
    #|    local.set 1
    #|    local.get 0
    #|    local.get 1
    #|    call $use
    #|    local.get 1
    #|    call $release))
  let original = pass_test_module_from_wat(input)
  for
    pass_name in [
      "simplify-locals-notee-nostructure", "simplify-locals-nostructure", "simplify-locals",
    ] {
    let trace : Array[String] = []
    let optimized = match
      pass_test_run_pipeline(
        input,
        [pass_name],
        options=HotPipelineOptions::new(
          trace=Some(fn(line) { trace.push(line) }),
        ),
      ) {
      Ok(mod_) => mod_
      Err(err) => fail("expected multi-call lifetime success, got \{err}")
    }
    @debug.assert_eq(optimized, original)
    assert_true(
      trace.any(fn(line) {
        line.contains("reason=call-result-multi-call-lifetime")
      }),
      msg=trace.to_string(),
    )
  }
}

///|
test "simplify-locals-nostructure preserves long-argument call-result lifetimes" {
  let input =
    #|(module
    #|  (func $make (param i32) (result i32) local.get 0)
    #|  (func $use (param i32 i32 i32 i32 i32 i32 i32) (result i32)
    #|    local.get 0)
    #|  (func $release (param i32))
    #|  (func (param i32 i32 i32) (result i32) (local i32)
    #|    local.get 0
    #|    call $make
    #|    local.set 3
    #|    local.get 1
    #|    local.get 2
    #|    local.get 3
    #|    i32.const 62672
    #|    i32.const 62656
    #|    i32.const 74432
    #|    i32.const 0
    #|    call $use
    #|    local.get 3
    #|    call $release))
  let original = pass_test_module_from_wat(input)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["simplify-locals-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected long-argument lifetime success, got \{err}")
  }
  @debug.assert_eq(optimized, original)
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=call-result-multi-call-lifetime")
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-notee-nostructure preserves load result copy boundaries" {
  let input =
    #|(module
    #|  (memory 1)
    #|  (func (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    i32.load
    #|    local.set 1
    #|    local.get 1
    #|    return))
  let original = pass_test_module_from_wat(input)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["simplify-locals-notee-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected load result copy boundary success, got \{err}")
  }
  @debug.assert_eq(optimized, original)
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=load-call-adjacent-copy-simplify-locals-notee-noop")
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-notee-nostructure defers call and bulk-memory effect meshes" {
  let input =
    #|(module
    #|  (memory 1)
    #|  (func $make (result i32) i32.const 1)
    #|  (func (result i32) (local i32)
    #|    i32.const 0
    #|    i32.const 0
    #|    i32.const 1
    #|    memory.fill
    #|    call $make
    #|    local.set 0
    #|    local.get 0))
  let original = pass_test_module_from_wat(input)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["simplify-locals-notee-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected call/bulk-memory fail-closed success, got \{err}")
  }
  @debug.assert_eq(optimized, original)
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=call-bulk-memory-effect-order-simplify-locals-notee-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-notee-nostructure preserves stack-carried tee lifetimes" {
  let input =
    #|(module
    #|  (func $use (param i32 i32))
    #|  (func $release (param i32))
    #|  (func (param i32) (local i32 i32)
    #|    local.get 0
    #|    i32.const 0
    #|    local.set 1
    #|    local.tee 2
    #|    local.get 1
    #|    call $use
    #|    local.get 2
    #|    call $release))
  let original = pass_test_module_from_wat(input)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["simplify-locals-notee-nostructure"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected stack-carried tee lifetime success, got \{err}")
  }
  @debug.assert_eq(optimized, original)
  assert_true(
    trace.any(fn(line) { line.contains("reason=call-local-tee-lifetime") }),
    msg=trace.to_string(),
  )
}

///|
test "simplify-locals-nostructure preserves call-local-tee lifetimes" {
  // The tee owns a call result across a consumer call and a later release call.
  // Forwarding it before the producer reads an uninitialized local and moves the
  // release ahead of the consumer.
  let input =
    #|(module
    #|  (type $make (func (param i32) (result i32)))
    #|  (type $use (func (param i32) (result i32)))
    #|  (type $release (func (param i32)))
    #|  (import "m" "make" (func $make (type $make)))
    #|  (import "m" "use" (func $use (type $use)))
    #|  (import "m" "release" (func $release (type $release)))
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    local.get 0
    #|    call $make
    #|    local.tee 1
    #|    call $use
    #|    local.get 1
    #|    call $release
    #|    local.set 2
    #|    local.get 2
    #|    if
    #|      nop
    #|    end
    #|    local.get 2))
  let original = pass_test_module_from_wat(input)
  for pass_name in ["simplify-locals-nostructure", "simplify-locals"] {
    let trace : Array[String] = []
    let optimized = match
      pass_test_run_pipeline(
        input,
        [pass_name],
        options=HotPipelineOptions::new(
          trace=Some(fn(line) { trace.push(line) }),
        ),
      ) {
      Ok(mod_) => mod_
      Err(err) => fail("expected call-local-tee lifetime success, got \{err}")
    }
    @debug.assert_eq(optimized, original)
    assert_true(
      trace.any(fn(line) { line.contains("reason=call-local-tee-lifetime") }),
      msg=trace.to_string(),
    )
  }
}

///|
test "simplify-locals-nostructure preserves consumers before argument releases" {
  let input =
    #|(module
    #|  (type $combine-type (func (param i32 i32 i32) (result i32)))
    #|  (type $release-type (func (param i32)))
    #|  (type $consume-type (func (param i32 i32) (result i32)))
    #|  (import "m" "combine" (func $combine (type $combine-type)))
    #|  (import "m" "release" (func $release (type $release-type)))
    #|  (import "m" "consume" (func $consume (type $consume-type)))
    #|  (func (param i32 i32) (result i32) (local i32 i32 i32 i32)
    #|    local.get 1
    #|    i32.eqz
    #|    if (result i32)
    #|      i32.const 46768
    #|      local.set 4
    #|      i32.const 46768
    #|      local.set 5
    #|      local.get 4
    #|      local.get 5
    #|      i32.const -1
    #|      call $combine
    #|      local.get 4
    #|      call $release
    #|      local.get 5
    #|      call $release
    #|    else
    #|      local.get 1
    #|    end
    #|    local.set 2
    #|    local.get 0
    #|    local.get 2
    #|    call $consume
    #|    local.get 2
    #|    call $release))
  let original = pass_test_module_from_wat(input)
  for pass_name in ["simplify-locals-nostructure", "simplify-locals"] {
    let trace : Array[String] = []
    let optimized = match
      pass_test_run_pipeline(
        input,
        [pass_name],
        options=HotPipelineOptions::new(
          trace=Some(fn(line) { trace.push(line) }),
        ),
      ) {
      Ok(mod_) => mod_
      Err(err) => fail("expected consumer/release lifetime success, got \{err}")
    }
    @debug.assert_eq(optimized, original)
    let reason = if pass_name == "simplify-locals-nostructure" {
      "reason=call-argument-direct-release-simplify-locals-nostructure-noop"
    } else {
      "reason=call-argument-direct-release-simplify-locals-noop"
    }
    assert_true(
      trace.any(fn(line) { line.contains(reason) }),
      msg=trace.to_string(),
    )
  }
}

///|
test "simplify-locals variants preserve loaded values before releases" {
  let input =
    #|(module
    #|  (import "env" "release" (func $release (param i32)))
    #|  (memory 1)
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    local.set 1
    #|    local.get 0
    #|    i32.load
    #|    local.get 0
    #|    call $release))
  let original = pass_test_module_from_wat(input)
  for pass_name in ["simplify-locals-nostructure", "simplify-locals"] {
    let trace : Array[String] = []
    let optimized = match
      pass_test_run_pipeline(
        input,
        [pass_name],
        options=HotPipelineOptions::new(
          trace=Some(fn(line) { trace.push(line) }),
        ),
      ) {
      Ok(mod_) => mod_
      Err(err) => fail("expected load/release lifetime success, got \{err}")
    }
    @debug.assert_eq(optimized, original)
    let reason = if pass_name == "simplify-locals-nostructure" {
      "reason=load-before-release-simplify-locals-nostructure-noop"
    } else {
      "reason=load-before-release-simplify-locals-noop"
    }
    assert_true(
      trace.any(fn(line) { line.contains(reason) }),
      msg=trace.to_string(),
    )
  }
}

///|
test "simplify-locals-nostructure bounds structured startup initializer convergence" {
  // The large debug-WASI initializer combines low-local tee carriers, calls,
  // globals, stores, and small structured checks. That exact mix reaches the
  // recursive root-forwarding path before the unstructured startup guard.
  let input =
    #|(module
    #|  (type $none_i32 (func (result i32)))
    #|  (type $i32_i32 (func (param i32) (result i32)))
    #|  (import "env" "make" (func $make (type $none_i32)))
    #|  (import "env" "use" (func $use (type $i32_i32)))
    #|  (memory 1)
    #|  (global $g0 (mut i32) (i32.const 0))
    #|  (global $g1 (mut i32) (i32.const 0))
    #|  (func (export "run") (local i32 i32 i32 i32 i32 i32 i32)
    #|    call $make local.tee 0 call $use global.set $g0
    #|    local.get 0
    #|    if
    #|      local.get 0 call $use global.set $g1
    #|    end
    #|    call $make local.tee 1 call $use drop
    #|    call $make local.tee 2 call $use drop
    #|    i32.const 8 call $use local.tee 3
    #|    i32.const 1 i32.store
    #|    local.get 3 i32.const 4 i32.store
    #|    local.get 0 drop
    #|    local.get 1 drop
    #|    local.get 2 drop))
  let original = pass_test_module_from_wat(input)
  for pass_name in ["simplify-locals-nostructure", "simplify-locals"] {
    let trace : Array[String] = []
    let optimized = match
      pass_test_run_pipeline(
        input,
        [pass_name],
        options=HotPipelineOptions::new(
          trace=Some(fn(line) { trace.push(line) }),
        ),
      ) {
      Ok(mod_) => mod_
      Err(err) =>
        fail("expected bounded structured startup \{pass_name}, got \{err}")
    }
    @debug.assert_eq(optimized, original)
    assert_true(
      trace.any(fn(line) {
        line.contains(
          "reason=structured-startup-initializer-call-store-local-tee",
        )
      }),
      msg=trace.to_string(),
    )
  }
}

///|
test "simplify-locals-nostructure bounds startup initializer convergence" {
  let input =
    #|(module
    #|  (type $i32_i32 (func (param i32) (result i32)))
    #|  (type $i64_i32 (func (param i64) (result i32)))
    #|  (type $none_i32 (func (result i32)))
    #|  (import "env" "f8" (func $f8 (type $i32_i32)))
    #|  (import "env" "f20" (func $f20 (type $none_i32)))
    #|  (import "env" "f21" (func $f21 (type $i32_i32)))
    #|  (import "env" "f22" (func $f22 (type $i64_i32)))
    #|  (import "env" "f23" (func $f23 (type $i32_i32)))
    #|  (import "env" "f31" (func $f31 (type $i32_i32)))
    #|  (memory 3)
    #|  (global $g2 (mut i32) (i32.const 0))
    #|  (global $g3 (mut f64) (f64.const 0))
    #|  (global $g4 (mut f64) (f64.const 0))
    #|  (global $g5 (mut f64) (f64.const 0))
    #|  (global $g6 (mut i32) (i32.const 0))
    #|  (global $g7 (mut i32) (i32.const 0))
    #|  (global $g8 (mut i32) (i32.const 0))
    #|  (global $g9 (mut i32) (i32.const 0))
    #|  (global $g10 (mut i32) (i32.const 0))
    #|  (global $g11 (mut i32) (i32.const 0))
    #|  (global $g12 (mut i32) (i32.const 0))
    #|  (global $g13 (mut i32) (i32.const 0))
    #|  (func (export "run") (local i32 i32 i32 i32 i32 i32 i32)
    #|    i32.const 10000 global.set $g2
    #|    f64.const nan global.set $g3
    #|    f64.const inf global.set $g4
    #|    f64.const -inf global.set $g5
    #|    i32.const 0 call $f21 global.set $g6
    #|    i64.const 0 call $f22 global.set $g7
    #|    i32.const 0 call $f23 global.set $g8
    #|    i32.const 8 call $f31 call $f21 global.set $g9
    #|    i32.const 8 call $f31 call $f21 global.set $g10
    #|    i32.const 10016 local.set 4
    #|    i32.const 8 call $f8 local.tee 6
    #|    i32.const 1573120 i32.store offset=4 align=1
    #|    local.get 6 i32.const 0 i32.store offset=8 align=1
    #|    local.get 6 local.get 4 i32.store offset=12 align=1
    #|    local.get 6 call $f21 global.set $g11
    #|    i32.const 0 call $f21 global.set $g12
    #|    call $f20 global.set $g13))
  for pass_name in ["simplify-locals-nostructure", "simplify-locals"] {
    let optimized = match pass_test_run_pipeline(input, [pass_name]) {
      Ok(mod_) => mod_
      Err(err) =>
        fail("expected bounded startup initializer \{pass_name}, got \{err}")
    }
    match @validate.validate_module(optimized) {
      Ok(_) => ()
      Err(err) =>
        fail("expected bounded startup initializer \{pass_name}, got \{err}")
    }
  }
}
