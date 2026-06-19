///|
fn optimize_instructions_large_local_fixture() -> String {
  let out = StringBuilder::new()
  out.write_string("(module (func (local i32")
  for i = 0; i < 1024; i = i + 1 {
    let _ = i
    out.write_string(" i32")
  }
  out.write_string(") i32.const 0 i32.eqz drop))")
  out.to_string()
}

///|
fn optimize_instructions_large_lowered_fixture() -> String {
  let out = StringBuilder::new()
  out.write_string("(module (func (local")
  for i = 0; i < 65; i = i + 1 {
    let _ = i
    out.write_string(" i32")
  }
  out.write_string(")")
  for i = 0; i < 260; i = i + 1 {
    let _ = i
    out.write_string(" i32.const 0 drop")
  }
  out.write_string("))")
  out.to_string()
}

///|
fn optimize_instructions_structured_gate_fixture(
  repeats : Int,
  extra_calls : Int,
  extra_writes : Int,
) -> String {
  let out = StringBuilder::new()
  out.write_string(
    "(module (import \"m\" \"touch\" (func $touch)) (func (local i32)",
  )
  for i = 0; i < repeats; i = i + 1 {
    out.write_string(" (block $b")
    out.write_string(i.to_string())
    out.write_string(
      " i32.const 0 if call $touch i32.const 0 local.set 0 br $b",
    )
    out.write_string(i.to_string())
    out.write_string(" else i32.const 1 local.set 0 return end)")
  }
  for i = 0; i < extra_calls; i = i + 1 {
    let _ = i
    out.write_string(" call $touch")
  }
  for i = 0; i < extra_writes; i = i + 1 {
    let _ = i
    out.write_string(" i32.const 0 local.set 0")
  }
  out.write_string("))")
  out.to_string()
}

///|
fn optimize_instructions_loop_gate_fixture() -> String {
  (
    #|(module
    #|  (import "m" "touch" (func $touch))
    #|  (func (local i32)
    #|    (loop $l
    #|      i32.const 0
    #|      if
    #|        call $touch
    #|        i32.const 0
    #|        local.set 0
    #|        i32.const 1
    #|        local.set 0
    #|        i32.const 2
    #|        local.set 0
    #|        i32.const 3
    #|        local.set 0
    #|        br $l
    #|      end)))
    #|,
  )
}

///|
fn optimize_instructions_assert_skip_reason(
  text : String,
  reason : String,
) -> Unit raise {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      text,
      ["optimize-instructions"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected optimize-instructions skip success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[optimize-instructions]:skip-raw reason=\{reason}")
    }),
    msg="expected skip reason \{reason} in \{trace}",
  )
}

///|
test "optimize-instructions skips very large local-heavy functions" {
  optimize_instructions_assert_skip_reason(
    optimize_instructions_large_local_fixture(),
    "large-local-optimize-instructions",
  )
}

///|
test "optimize-instructions skips large lowered functions" {
  optimize_instructions_assert_skip_reason(
    optimize_instructions_large_lowered_fixture(),
    "large-lowered-optimize-instructions-noop",
  )
}

///|
test "optimize-instructions skips structured call and branch meshes with precise reason" {
  optimize_instructions_assert_skip_reason(
    optimize_instructions_structured_gate_fixture(10, 6, 0),
    "structured-call-branch-optimize-instructions-noop",
  )
}

///|
test "optimize-instructions skips block return call branch meshes below structured threshold" {
  optimize_instructions_assert_skip_reason(
    optimize_instructions_structured_gate_fixture(5, 7, 10),
    "block-return-call-branch-optimize-instructions-noop",
  )
}

///|
test "optimize-instructions skips loop branch local writes below block threshold" {
  optimize_instructions_assert_skip_reason(
    optimize_instructions_loop_gate_fixture(),
    "loop-branch-local-write-optimize-instructions-noop",
  )
}

///|
test "optimize-instructions public pipeline still cleans neutral add outside raw gates" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (param i32) (result i32)
        #|    local.get 0
        #|    i32.const 0
        #|    i32.add))
        #|,
      ),
      ["optimize-instructions"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected optimize-instructions cleanup success, got \{err}")
  }
  assert_false(
    trace.any(fn(line) { line.contains("pass[optimize-instructions]:skip-raw") }),
    msg="unexpected raw skip in \{trace}",
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("i32.add"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
}

///|
test "optimize-instructions skips functions mixing loads and calls" {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (import "m" "touch" (func $touch))
        #|  (memory 1)
        #|  (func (param $ptr i32)
        #|    local.get $ptr
        #|    i32.load
        #|    drop
        #|    call $touch
        #|    i32.const 0
        #|    i32.eqz
        #|    drop))
        #|,
      ),
      ["optimize-instructions"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected load-call optimize-instructions skip, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[optimize-instructions]:skip-raw reason=load-call-optimize-instructions-noop",
      )
    }),
  )
}

///|
test "optimize-instructions skips call-local-write functions" {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (import "m" "touch" (func $touch))
        #|  (func
        #|    (local i32)
        #|    call $touch
        #|    i32.const 0
        #|    local.set 0
        #|    i32.const 0
        #|    i32.eqz
        #|    drop))
        #|,
      ),
      ["optimize-instructions"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected call-local-write optimize-instructions skip, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[optimize-instructions]:skip-raw reason=call-local-write-optimize-instructions-noop",
      )
    }),
  )
}

///|
test "optimize-instructions skips stack-carried values across effect barriers" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (import "m" "decref" (func $decref (param i32)))
        #|  (memory 1)
        #|  (func (param $ptr i32) (result i32)
        #|    (local $out i32)
        #|    local.get $ptr
        #|    i32.load
        #|    local.get $ptr
        #|    call $decref
        #|    local.set $out
        #|    i32.const 0
        #|    i32.eqz
        #|    drop
        #|    local.get $out))
        #|,
      ),
      ["optimize-instructions"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected stack-carried optimize-instructions skip success, got \{err}",
      )
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[optimize-instructions]:skip-raw reason=stack-carried-effect-optimize-instructions-noop",
      )
    }),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  optimize_instructions_assert_strings_in_order(pretty, [
    "i32.load", "call (Func 0)", "local.set",
  ])
}

///|
test "optimize-instructions keeps i32.eqz on constant zero" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (result i32) i32.const 0 i32.eqz))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_eqz()),
  )
  @debug.assert_eq(@ir.hot_child_count(func, root), 1)
  let operand = @ir.hot_child_get(func, root, 0)
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, operand).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )
}

///|
fn optimize_instructions_test_run_hot(text : String) -> @ir.HotFunc {
  let func = pass_test_lift_first_func(text)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => func
    Err(err) =>
      abort("expected optimize-instructions hot pass success, got \{err}")
  }
}

///|
fn optimize_instructions_test_count_substring(
  text : String,
  needle : String,
) -> Int {
  if needle.length() == 0 {
    return 0
  }
  let mut count = 0
  let limit = text.length() - needle.length()
  let mut i = 0
  while i <= limit {
    if text.sub(start=i, end=i + needle.length()).to_owned() == needle {
      count += 1
      i += needle.length()
    } else {
      i += 1
    }
  }
  count
}

///|
fn optimize_instructions_assert_strings_in_order(
  text : String,
  needles : Array[String],
) -> Unit raise {
  let mut start = 0
  for needle in needles {
    let mut found : Int? = None
    let limit = text.length() - needle.length()
    let mut i = start
    while i <= limit {
      if text.sub(start=i, end=i + needle.length()).to_owned() == needle {
        found = Some(i)
        break
      }
      i += 1
    }
    match found {
      Some(idx) => start = idx + needle.length()
      None => fail("expected `\{needle}` after offset \{start} in `\{text}`")
    }
  }
}

///|
fn optimize_instructions_shared_dag_fixture(depth : Int) -> @ir.HotFunc {
  let func = @ir.HotFunc::new()
  let mut value = @ir.hot_build_const_i32(func, @lib.I32(0))
  for i = 0; i < depth; i = i + 1 {
    let _ = i
    let lhs = @ir.hot_build_binary(
      func,
      @lib.ValType::i32(),
      value,
      @ir.hot_build_const_i32(func, @lib.I32(1)),
    )
    @ir.hot_node_exact_instr_set(func, lhs, @lib.Instruction::i32_add())
    let rhs = @ir.hot_build_binary(
      func,
      @lib.ValType::i32(),
      value,
      @ir.hot_build_const_i32(func, @lib.I32(2)),
    )
    @ir.hot_node_exact_instr_set(func, rhs, @lib.Instruction::i32_add())
    value = @ir.hot_build_binary(func, @lib.ValType::i32(), lhs, rhs)
    @ir.hot_node_exact_instr_set(func, value, @lib.Instruction::i32_add())
  }
  @ir.hot_root_append(func, @ir.hot_build_drop(func, value))
  func
}

///|
test "optimize-instructions keeps shared eqz constant children live" {
  let func = pass_test_lift_first_func(
    "(module (func (result i32) i32.const 0 i32.eqz))",
  )
  let eqz = @ir.hot_root_get(func, 0)
  let shared = @ir.hot_child_get(func, eqz, 0)
  let drop_ = @ir.hot_build_drop(func, shared)
  @ir.hot_root_append(func, drop_)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected optimize-instructions shared-child success, got \{err}")
  }

  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_eqz()),
  )
  @debug.assert_eq(@ir.hot_child_get(func, root, 0), shared)
  assert_true(@ir.hot_node_is_live(func, shared))
  @debug.assert_eq(@ir.hot_child_get(func, drop_, 0), shared)
}

///|
test "optimize-instructions keeps i64.eqz on non-zero constants" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (result i32) i64.const 9 i64.eqz))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i64_eqz()),
  )
  @debug.assert_eq(@ir.hot_child_count(func, root), 1)
  let operand = @ir.hot_child_get(func, root, 0)
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, operand).imm0),
    @ir.HotConstPayload::i64_const(@lib.I64(9L)),
  )
}

///|
test "optimize-instructions rewrites eqz on sub into eq" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) local.get 0 local.get 1 i32.sub i32.eqz))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_eq()),
  )
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected lhs of eqz(sub) rewrite to remain the original lhs")
  }
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected rhs of eqz(sub) rewrite to remain the original rhs")
  }
}

///|
test "optimize-instructions rewrites eqz on add const into eq negated const" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 5 i32.add i32.eqz))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_eq()),
  )
  let rhs = @ir.hot_child_get(func, root, 1)
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(-5)),
  )
}

///|
test "optimize-instructions folds constant false void ifs to nops" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func i32.const 0 if nop else nop end i64.const 3 drop))",
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected optimize-instructions success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("i64.const I64(3)"), msg=pretty)
}

///|
test "optimize-instructions folds constant true result ifs to the chosen arm" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 1 if (result i32) i32.const 7 else i32.const 9 end))",
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected optimize-instructions success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "optimize-instructions constant-if folding preserves hot label ownership" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (result i32) i32.const 1 if (result i32) i32.const 7 else i32.const 9 end))",
  )
  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block => ()
    other => fail("expected constant result if to become a block, got \{other}")
  }
  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected constant-if fold label owners to verify, got \{err}")
  }
}

///|
test "optimize-instructions preserves block-wrapped try_table catch depths in ref locals" {
  let source =
    #|(module
    #|  (type $box (sub (struct)))
    #|  (func $f (param i32) (result (ref null $box)) (local (ref null $box))
    #|    block
    #|      try_table (catch_all 0)
    #|        i32.const 0
    #|        if
    #|          ref.null $box
    #|          local.set 1
    #|        else
    #|          ref.null $box
    #|          local.set 1
    #|        end
    #|      end
    #|    end
    #|    local.get 1)
    #|  (func (export "run") (result (ref null $box))
    #|    i32.const 99
    #|    call $f))
  let optimized = match
    pass_test_run_pipeline(source, ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected optimize-instructions try_table ref-local success, got \{err}",
      )
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions try_table ref-local output to validate, got \{err}",
      )
  }
}

///|
test "optimize-instructions folds select with constant false and pure dead arm" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (result i32) (select (i32.add (i32.const 1) (i32.const 2)) (i32.const 7) (i32.const 0))))",
  )
  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Const =>
      @debug.assert_eq(
        @ir.hot_const_get(func, @ir.hot_node_get(func, root).imm0),
        @ir.HotConstPayload::i32_const(@lib.I32(7)),
      )
    _ => fail("expected constant-false select to become the false arm")
  }
}

///|
test "optimize-instructions folds select with constant true and pure dead arm" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) (select (local.get 0) (i32.add (i32.const 1) (i32.const 2)) (i32.const 1))))",
  )
  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected constant-true select to become the true arm")
  }
}

///|
test "optimize-instructions preserves select when constant dead arm has call effects" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (result i32) (select (call $effect) (i32.const 7) (i32.const 0))) (func $effect (result i32) i32.const 9))",
  )
  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Select => ()
    _ => fail("expected select with effectful dead arm to be preserved")
  }
}

///|
test "optimize-instructions canonicalizes i32.eq zero into eqz" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 0 i32.eq))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_eqz()),
  )
  @debug.assert_eq(@ir.hot_child_count(func, root), 1)
}

///|
test "optimize-instructions canonicalizes i64.eq zero into eqz" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i32) local.get 0 i64.const 0 i64.eq))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i64_eqz()),
  )
  @debug.assert_eq(@ir.hot_child_count(func, root), 1)
}

///|
test "optimize-instructions keeps i32.rem zero compares in eq form" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 64 i32.rem_s i32.const 0 i32.eq))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_eq()),
  )
  @debug.assert_eq(@ir.hot_child_count(func, root), 2)
}

///|
test "optimize-instructions rewrites add with a negative constant into sub" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const -5 i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_sub()),
  )
  let rhs = @ir.hot_child_get(func, root, 1)
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(5)),
  )
}

///|
test "optimize-instructions preserves signed-leb-friendly negative adds" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const -64 i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_add()),
  )
  let rhs = @ir.hot_child_get(func, root, 1)
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(-64)),
  )
}

///|
test "optimize-instructions preserves positive add immediates for parity" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 64 i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_add()),
  )
  let rhs = @ir.hot_child_get(func, root, 1)
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(64)),
  )
}

///|
test "optimize-instructions keeps leading positive const adds in add form" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) i32.const 64 local.get 0 i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_add()),
  )
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::Const => ()
    _ => fail("expected leading positive add const to stay on the lhs")
  }
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, lhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(64)),
  )
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected non-constant positive add operand to stay on the rhs")
  }
}

///|
test "optimize-instructions rewrites add with trailing zero-sub into sub" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) local.get 0 i32.const 0 local.get 1 i32.sub i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_sub()),
  )
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected x + (0 - y) rewrite to preserve the lhs local")
  }
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected x + (0 - y) rewrite to expose the rhs local")
  }
}

///|
test "optimize-instructions keeps leading zero-sub add ordering" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) i32.const 0 local.get 0 i32.sub local.get 1 i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_add()),
  )
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, lhs),
    Some(@lib.Instruction::i32_sub()),
  )
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected trailing add local to stay on the rhs")
  }
}

///|
test "optimize-instructions folds exact integer constant subtraction" {
  let i32_func = optimize_instructions_test_run_hot(
    "(module (func (result i32) i32.const 84 i32.const 3 i32.sub))",
  )
  let i32_root = @ir.hot_root_get(i32_func, 0)
  match @ir.hot_node_get(i32_func, i32_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected i32.const subtraction to fold to one const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(i32_func, @ir.hot_node_get(i32_func, i32_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(81)),
  )

  let i32_wrap_func = optimize_instructions_test_run_hot(
    "(module (func (result i32) i32.const 3 i32.const 84 i32.sub))",
  )
  let i32_wrap_root = @ir.hot_root_get(i32_wrap_func, 0)
  @debug.assert_eq(
    @ir.hot_const_get(
      i32_wrap_func,
      @ir.hot_node_get(i32_wrap_func, i32_wrap_root).imm0,
    ),
    @ir.HotConstPayload::i32_const(@lib.I32(-81)),
  )

  let i64_func = optimize_instructions_test_run_hot(
    "(module (func (result i64) i64.const 99 i64.const 5 i64.sub))",
  )
  let i64_root = @ir.hot_root_get(i64_func, 0)
  match @ir.hot_node_get(i64_func, i64_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected i64.const subtraction to fold to one const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(i64_func, @ir.hot_node_get(i64_func, i64_root).imm0),
    @ir.HotConstPayload::i64_const(@lib.I64(94L)),
  )

  let i64_wrap_func = optimize_instructions_test_run_hot(
    "(module (func (result i64) i64.const 5 i64.const 99 i64.sub))",
  )
  let i64_wrap_root = @ir.hot_root_get(i64_wrap_func, 0)
  @debug.assert_eq(
    @ir.hot_const_get(
      i64_wrap_func,
      @ir.hot_node_get(i64_wrap_func, i64_wrap_root).imm0,
    ),
    @ir.HotConstPayload::i64_const(@lib.I64(-94L)),
  )
}

///|
test "optimize-instructions canonicalizes default scalar float spellings" {
  let f32_func = optimize_instructions_test_run_hot(
    "(module (func (param f32) (result f32) local.get 0 f32.const 2.5 f32.sub))",
  )
  let f32_root = @ir.hot_root_get(f32_func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(f32_func, f32_root),
    Some(@lib.Instruction::f32_add()),
  )
  let f32_rhs = @ir.hot_child_get(f32_func, f32_root, 1)
  @debug.assert_eq(
    @ir.hot_const_get(f32_func, @ir.hot_node_get(f32_func, f32_rhs).imm0),
    @ir.HotConstPayload::f32_const(@lib.F32(-2.5)),
  )

  let f64_func = optimize_instructions_test_run_hot(
    "(module (func (param f64) (result f64) local.get 0 f64.const 2 f64.div))",
  )
  let f64_root = @ir.hot_root_get(f64_func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(f64_func, f64_root),
    Some(@lib.Instruction::f64_mul()),
  )
  let f64_rhs = @ir.hot_child_get(f64_func, f64_root, 1)
  @debug.assert_eq(
    @ir.hot_const_get(f64_func, @ir.hot_node_get(f64_func, f64_rhs).imm0),
    @ir.HotConstPayload::f64_const(@lib.F64(0.5)),
  )
}

///|
test "optimize-instructions folds i32.wrap_i64 constants" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (result i32) i64.const 4294967295 i32.wrap_i64))",
  )
  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected i32.wrap_i64 of a const to fold")
  }
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(-1)),
  )
}

///|
test "optimize-instructions expands one-byte memory.copy to load8/store8" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $dst i32) (param $src i32)
        #|    local.get $dst
        #|    local.get $src
        #|    i32.const 1
        #|    memory.copy))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected memory.copy optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("memory.copy"), msg=pretty)
  assert_true(pretty.contains("i32.load8u"), msg=pretty)
  assert_true(pretty.contains("i32.store8"), msg=pretty)
}

///|
test "optimize-instructions expands tiny constant memory.fill to store" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $dst i32)
        #|    local.get $dst
        #|    i32.const 7
        #|    i32.const 1
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected memory.fill optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("memory.fill"), msg=pretty)
  assert_true(pretty.contains("i32.store8"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
}

///|
test "optimize-instructions expands constant two-byte memory.fill to store16" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $dst i32)
        #|    local.get $dst
        #|    i32.const 171
        #|    i32.const 2
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected two-byte memory.fill optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("memory.fill"), msg=pretty)
  assert_true(pretty.contains("i32.store16"), msg=pretty)
  assert_true(pretty.contains("I32(43947)"), msg=pretty)
}

///|
test "optimize-instructions expands constant four-byte memory.fill to store" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $dst i32)
        #|    local.get $dst
        #|    i32.const 127
        #|    i32.const 4
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected four-byte memory.fill optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("memory.fill"), msg=pretty)
  assert_true(pretty.contains("i32.store"), msg=pretty)
  assert_true(pretty.contains("I32(2139062143)"), msg=pretty)
}

///|
test "optimize-instructions expands constant eight-byte memory.fill to store" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $dst i32)
        #|    local.get $dst
        #|    i32.const 1
        #|    i32.const 8
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected eight-byte memory.fill optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("memory.fill"), msg=pretty)
  assert_true(pretty.contains("i64.store"), msg=pretty)
  assert_true(pretty.contains("I64(72340172838076673)"), msg=pretty)
}

///|
test "optimize-instructions expands local two-byte memory.fill to store16" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $dst i32) (param $value i32)
        #|    local.get $dst
        #|    local.get $value
        #|    i32.const 2
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected local two-byte memory.fill optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("memory.fill"), msg=pretty)
  assert_true(pretty.contains("i32.store16"), msg=pretty)
  assert_true(pretty.contains("i32.and"), msg=pretty)
  assert_true(pretty.contains("I32(255)"), msg=pretty)
  assert_true(pretty.contains("i32.mul"), msg=pretty)
  assert_true(pretty.contains("I32(257)"), msg=pretty)
}

///|
test "optimize-instructions expands local four-byte memory.fill to store" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $dst i32) (param $value i32)
        #|    local.get $dst
        #|    local.get $value
        #|    i32.const 4
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected local four-byte memory.fill optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("memory.fill"), msg=pretty)
  assert_true(pretty.contains("i32.store"), msg=pretty)
  assert_true(pretty.contains("i32.and"), msg=pretty)
  assert_true(pretty.contains("I32(255)"), msg=pretty)
  assert_true(pretty.contains("i32.mul"), msg=pretty)
  assert_true(pretty.contains("I32(16843009)"), msg=pretty)
}

///|
test "optimize-instructions keeps wider effectful memory.fill values" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func $get (result i32) i32.const 3)
        #|  (func (param $dst i32)
        #|    local.get $dst
        #|    call $get
        #|    i32.const 2
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected effectful memory.fill boundary success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("memory.fill"), msg=pretty)
}

///|
test "optimize-instructions keeps zero-size memory.fill without trap mode support" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $dst i32)
        #|    local.get $dst
        #|    i32.const 7
        #|    i32.const 0
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected zero-size memory.fill boundary success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.fill"), msg=pretty)
}

///|
test "optimize-instructions removes redundant sign extensions from signed loads" {
  let func = optimize_instructions_test_run_hot(
    "(module (memory 1) (func (param i32) (result i32) local.get 0 i32.load8_s i32.extend8_s))",
  )
  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Load => ()
    _ =>
      fail("expected redundant sign extension after signed load to fold away")
  }
  match @ir.hot_node_exact_instr(func, root) {
    Some(@lib.Instruction::I32Load8S(_)) => ()
    other =>
      fail(
        "expected i32.load8_s after redundant extension removal, got \{other}",
      )
  }
}

///|
test "optimize-instructions uses local sign facts after fallthrough sets" {
  let func = optimize_instructions_test_run_hot(
    "(module (memory 1) (func (param i32) (result i32) (local i32) local.get 0 i32.load8_s local.set 1 local.get 1 i32.extend8_s))",
  )
  let root = @ir.hot_root_get(func, 1)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::LocalGet => ()
    _ =>
      fail(
        "expected local.get with signed-load fact to make extend8_s redundant",
      )
  }
  @debug.assert_eq(@ir.hot_node_get(func, root).imm0, 1)
}

///|
test "optimize-instructions preserves sign extensions for constants outside signed lane range" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (result i32) i32.const 255 i32.extend8_s))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_extend8s()),
  )
}

///|
test "optimize-instructions does not assume param sign facts" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.extend8_s))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_extend8s()),
  )
}

///|
test "optimize-instructions preserves loop-carried local sign extensions" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) (local i32) loop local.get 0 local.set 1 end local.get 1 i32.extend8_s))",
  )
  let root = @ir.hot_root_get(func, 1)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_extend8s()),
  )
}

///|
test "optimize-instructions rewrites shift sign-extension idioms" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 24 i32.shl i32.const 24 i32.shr_s))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_extend8s()),
  )
  let operand = @ir.hot_child_get(func, root, 0)
  match @ir.hot_node_get(func, operand).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected sign-extension rewrite to preserve the shifted operand")
  }
}

///|
test "optimize-instructions keeps trapping integer divisions unfurled" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (result i32) i32.const 84 i32.const 0 i32.div_s))",
  )
  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Binary => ()
    _ => fail("expected trapping division by zero to remain a binary op")
  }
  let rhs = @ir.hot_child_get(func, root, 1)
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )
}

///|
test "optimize-instructions removes neutral add and sub zero" {
  let add_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 8 i32.add i32.const 0 i32.add))",
  )
  let add_root = @ir.hot_root_get(add_func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(add_func, add_root),
    Some(@lib.Instruction::i32_add()),
  )
  let add_lhs = @ir.hot_child_get(add_func, add_root, 0)
  let add_rhs = @ir.hot_child_get(add_func, add_root, 1)
  match @ir.hot_node_get(add_func, add_lhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected neutral i32.add rewrite to expose the original lhs")
  }
  @debug.assert_eq(
    @ir.hot_const_get(add_func, @ir.hot_node_get(add_func, add_rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(8)),
  )

  let sub_func = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i64) local.get 0 i64.const 0 i64.sub))",
  )
  let sub_root = @ir.hot_root_get(sub_func, 0)
  match @ir.hot_node_get(sub_func, sub_root).op {
    @ir.HotOp::LocalGet => ()
    _ =>
      fail("expected neutral i64.sub rewrite to replace the node with its lhs")
  }
}

///|
test "optimize-instructions canonicalizes if eq zero into eqz without else" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (if (i32.eq (local.get 0) (i32.const 0)) (then nop))))",
  )
  let if_ = @ir.hot_root_get(func, 0)
  let cond = @ir.hot_child_get(func, if_, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, cond),
    Some(@lib.Instruction::i32_eqz()),
  )
  @debug.assert_eq(@ir.hot_child_count(func, cond), 1)
  match @ir.hot_node_get(func, @ir.hot_child_get(func, cond, 0)).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected if-condition eqz operand to remain the original value")
  }
}

///|
test "optimize-instructions collapses duplicate branch ifs in then regions after condition rewrites" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let outer_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let outer_label = @ir.hot_control_node_label(func, outer_block)
  let inner_compare = @ir.hot_build_compare(
    func,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  @ir.hot_node_exact_instr_set(func, inner_compare, @lib.Instruction::i32_eq())
  let branch_value = @ir.hot_build_local_get(func, 1)
  let inner_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    inner_compare,
    [@ir.hot_build_br(func, outer_label, values=[branch_value])],
    else_body=Some([@ir.hot_build_br(func, outer_label, values=[branch_value])]),
  )
  let outer_if = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_local_get(func, 0),
    [inner_if, @ir.hot_build_unreachable(func)],
    else_body=Some([@ir.hot_build_local_get(func, 1)]),
  )
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, outer_block),
    [outer_if],
  )
  @ir.hot_root_append(func, outer_block)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions duplicate-branch success, got \{err}",
      )
  }

  let then_region = @ir.hot_region_then_ref(func, outer_if)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_region), 1)
  let then_root = @ir.hot_region_get(func, then_region, 0)
  match @ir.hot_node_get(func, then_root).op {
    @ir.HotOp::Br => ()
    _ => fail("expected duplicate then-branch if to collapse to a branch")
  }
}

///|
test "optimize-instructions collapses duplicate branch ifs in single-root then regions after condition rewrites" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let carrier = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let carrier_label = @ir.hot_control_node_label(func, carrier)
  let middle = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let middle_label = @ir.hot_control_node_label(func, middle)
  let inner_compare = @ir.hot_build_compare(
    func,
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  )
  @ir.hot_node_exact_instr_set(func, inner_compare, @lib.Instruction::i32_eq())
  let inner_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    inner_compare,
    [@ir.hot_build_br(func, middle_label)],
    else_body=Some([@ir.hot_build_br(func, middle_label)]),
  )
  let outer_if = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_local_get(func, 0),
    [inner_if],
    else_body=Some([@ir.hot_build_local_get(func, 1)]),
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, middle), [
    @ir.hot_build_br(func, carrier_label, values=[outer_if]),
  ])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, carrier), [
    middle,
  ])
  @ir.hot_root_append(func, carrier)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions single-root duplicate-branch success, got \{err}",
      )
  }

  let then_region = @ir.hot_region_then_ref(func, outer_if)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_region), 1)
  let then_root = @ir.hot_region_get(func, then_region, 0)
  match @ir.hot_node_get(func, then_root).op {
    @ir.HotOp::Br => ()
    _ => fail("expected single-root duplicate then-branch if to collapse")
  }
}

///|
test "optimize-instructions replaces dead block fallthroughs after escaping ifs with unreachable" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let outer_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let outer_label = @ir.hot_control_node_label(func, outer_block)
  let escape_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [@ir.hot_build_return(func, [@ir.hot_build_const_i32(func, @lib.I32(1))])],
    else_body=Some([
      @ir.hot_build_br(func, outer_label, values=[
        @ir.hot_build_const_i32(func, @lib.I32(2)),
      ]),
    ]),
  )
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, outer_block),
    [escape_if, @ir.hot_build_const_i32(func, @lib.I32(0))],
  )
  @ir.hot_root_append(func, outer_block)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions dead-fallthrough cleanup success, got \{err}",
      )
  }

  let body = @ir.hot_region_body_ref(func, outer_block)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 2)
  let tail = @ir.hot_region_get(func, body, 1)
  match @ir.hot_node_get(func, tail).op {
    @ir.HotOp::Unreachable => ()
    _ =>
      fail("expected dead block fallthrough to canonicalize into unreachable")
  }
}

///|
test "optimize-instructions replaces dead block fallback branches after escaping ifs with unreachable" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let carrier = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let carrier_label = @ir.hot_control_node_label(func, carrier)
  let escape_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [@ir.hot_build_return(func, [@ir.hot_build_const_i32(func, @lib.I32(1))])],
    else_body=Some([
      @ir.hot_build_local_set(
        func,
        1,
        @ir.hot_build_const_i32(func, @lib.I32(2)),
      ),
      @ir.hot_build_br(func, carrier_label, values=[
        @ir.hot_build_local_get(func, 1),
      ]),
    ]),
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, carrier), [
    escape_if,
    @ir.hot_build_br(func, carrier_label, values=[
      @ir.hot_build_const_i32(func, @lib.I32(0)),
    ]),
  ])
  @ir.hot_root_append(func, carrier)
  @ir.hot_root_append(func, @ir.hot_build_local_get(func, 1))
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions dead-fallback-branch cleanup success, got \{err}",
      )
  }

  let body = @ir.hot_region_body_ref(func, carrier)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 2)
  let tail = @ir.hot_region_get(func, body, 1)
  match @ir.hot_node_get(func, tail).op {
    @ir.HotOp::Unreachable => ()
    _ => fail("expected dead fallback branch to canonicalize into unreachable")
  }
}

///|
test "optimize-instructions keeps outer fallthrough when inner branches only exit inner blocks" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let outer_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let inner_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let inner_label = @ir.hot_control_node_label(func, inner_block)
  let inner_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [
      @ir.hot_build_br(func, inner_label, values=[
        @ir.hot_build_const_i32(func, @lib.I32(1)),
      ]),
    ],
    else_body=Some([
      @ir.hot_build_br(func, inner_label, values=[
        @ir.hot_build_const_i32(func, @lib.I32(2)),
      ]),
    ]),
  )
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, inner_block),
    [inner_if, @ir.hot_build_const_i32(func, @lib.I32(0))],
  )
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, outer_block),
    [inner_block, @ir.hot_build_const_i32(func, @lib.I32(9))],
  )
  @ir.hot_root_append(func, outer_block)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions inner-branch fallthrough success, got \{err}",
      )
  }

  let outer_body = @ir.hot_region_body_ref(func, outer_block)
  @debug.assert_eq(@ir.hot_region_root_count(func, outer_body), 2)
  let outer_tail = @ir.hot_region_get(func, outer_body, 1)
  match @ir.hot_node_get(func, outer_tail).op {
    @ir.HotOp::Const => ()
    _ =>
      fail(
        "expected outer fallthrough to remain live when inner branches only exit the inner block",
      )
  }
}

///|
test "optimize-instructions preserves mixed-label fallback branches after non-fallthrough ifs" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let carrier = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let carrier_label = @ir.hot_control_node_label(func, carrier)
  let middle = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let middle_label = @ir.hot_control_node_label(func, middle)
  let escape_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [@ir.hot_build_br(func, middle_label)],
    else_body=Some([
      @ir.hot_build_br(func, carrier_label, values=[
        @ir.hot_build_const_i32(func, @lib.I32(2)),
      ]),
    ]),
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, middle), [
    escape_if,
    @ir.hot_build_br(func, carrier_label, values=[
      @ir.hot_build_const_i32(func, @lib.I32(0)),
    ]),
  ])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, carrier), [
    middle,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
  ])
  @ir.hot_root_append(func, carrier)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions mixed-label fallback cleanup success, got \{err}",
      )
  }

  let middle_body = @ir.hot_region_body_ref(func, middle)
  @debug.assert_eq(@ir.hot_region_root_count(func, middle_body), 2)
  let middle_tail = @ir.hot_region_get(func, middle_body, 1)
  match @ir.hot_node_get(func, middle_tail).op {
    @ir.HotOp::Br => ()
    _ =>
      fail("expected mixed-label fallback branch to remain a value-carrying br")
  }
  @debug.assert_eq(@ir.hot_node_get(func, middle_tail).imm0, carrier_label)
  let middle_tail_value = @ir.hot_child_get(func, middle_tail, 0)
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, middle_tail_value).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )
}

///|
test "optimize-instructions preserves outer fallback branches after nested return-or-inner-escape blocks" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let carrier = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let carrier_label = @ir.hot_control_node_label(func, carrier)
  let middle = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let middle_label = @ir.hot_control_node_label(func, middle)
  let escape_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [@ir.hot_build_return(func, [@ir.hot_build_const_i32(func, @lib.I32(9))])],
    else_body=Some([@ir.hot_build_br(func, middle_label)]),
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, middle), [
    escape_if,
  ])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, carrier), [
    middle,
    @ir.hot_build_br(func, carrier_label, values=[
      @ir.hot_build_const_i32(func, @lib.I32(0)),
    ]),
  ])
  @ir.hot_root_append(func, carrier)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions nested-return fallback cleanup success, got \{err}",
      )
  }

  let carrier_body = @ir.hot_region_body_ref(func, carrier)
  @debug.assert_eq(@ir.hot_region_root_count(func, carrier_body), 2)
  let carrier_tail = @ir.hot_region_get(func, carrier_body, 1)
  match @ir.hot_node_get(func, carrier_tail).op {
    @ir.HotOp::Br => ()
    _ => fail("expected outer fallback branch to remain a value-carrying br")
  }
  @debug.assert_eq(@ir.hot_node_get(func, carrier_tail).imm0, carrier_label)
  let carrier_tail_value = @ir.hot_child_get(func, carrier_tail, 0)
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, carrier_tail_value).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )
}

///|
test "optimize-instructions preserves value fallback branches after return-or-inner-label ifs" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let carrier = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let carrier_label = @ir.hot_control_node_label(func, carrier)
  let middle = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let middle_label = @ir.hot_control_node_label(func, middle)
  let escape_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [@ir.hot_build_return(func, [@ir.hot_build_const_i32(func, @lib.I32(9))])],
    else_body=Some([@ir.hot_build_br(func, middle_label)]),
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, middle), [
    escape_if,
    @ir.hot_build_br(func, carrier_label, values=[
      @ir.hot_build_const_i32(func, @lib.I32(0)),
    ]),
  ])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, carrier), [
    middle,
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  ])
  @ir.hot_root_append(func, carrier)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions inner-label fallback cleanup success, got \{err}",
      )
  }

  let middle_body = @ir.hot_region_body_ref(func, middle)
  @debug.assert_eq(@ir.hot_region_root_count(func, middle_body), 2)
  let middle_tail = @ir.hot_region_get(func, middle_body, 1)
  match @ir.hot_node_get(func, middle_tail).op {
    @ir.HotOp::Br => ()
    _ =>
      fail("expected inner-label fallback branch to remain a value-carrying br")
  }
  @debug.assert_eq(@ir.hot_node_get(func, middle_tail).imm0, carrier_label)
  let middle_tail_value = @ir.hot_child_get(func, middle_tail, 0)
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, middle_tail_value).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )
}

///|
test "optimize-instructions preserves zero sentinels under dropped value carriers" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let loop_ = @ir.hot_build_loop(func, @lib.BlockType::void_(), [])
  let loop_label = @ir.hot_control_node_label(func, loop_)
  let inner_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 1),
    [@ir.hot_build_return(func, [@ir.hot_build_const_i32(func, @lib.I32(7))])],
    else_body=Some([@ir.hot_build_br(func, loop_label)]),
  )
  let outer_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [@ir.hot_build_return(func, [@ir.hot_build_const_i32(func, @lib.I32(8))])],
    else_body=Some([
      inner_if,
      @ir.hot_build_drop(func, @ir.hot_build_const_i32(func, @lib.I32(0))),
    ]),
  )
  let carrier = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [outer_if, @ir.hot_build_const_i32(func, @lib.I32(0))],
  )
  let dropped = @ir.hot_build_drop(func, carrier)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, loop_), [
    dropped,
    @ir.hot_build_br(func, loop_label),
  ])
  @ir.hot_root_append(func, loop_)
  @ir.hot_root_append(func, @ir.hot_build_unreachable(func))
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions dropped-carrier sentinel preservation success, got \{err}",
      )
  }

  let outer_else = @ir.hot_region_else_ref(func, outer_if).unwrap()
  @debug.assert_eq(@ir.hot_region_root_count(func, outer_else), 2)
  let outer_else_tail = @ir.hot_region_get(func, outer_else, 1)
  match @ir.hot_node_get(func, outer_else_tail).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected dropped carrier else tail to keep explicit drop-zero sentinel",
      )
  }

  let carrier_body = @ir.hot_region_body_ref(func, carrier)
  @debug.assert_eq(@ir.hot_region_root_count(func, carrier_body), 2)
  let carrier_tail = @ir.hot_region_get(func, carrier_body, 1)
  match @ir.hot_node_get(func, carrier_tail).op {
    @ir.HotOp::Const => ()
    _ => fail("expected dropped carrier body to keep explicit zero sentinel")
  }
}

///|
test "optimize-instructions does not add unreachable tails to escaping if arms" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let carrier = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let carrier_label = @ir.hot_control_node_label(func, carrier)
  let nested = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [
      @ir.hot_build_br(func, carrier_label, values=[
        @ir.hot_build_const_i32(func, @lib.I32(2)),
      ]),
    ],
    else_body=Some([
      @ir.hot_build_return(func, [@ir.hot_build_const_i32(func, @lib.I32(9))]),
    ]),
  )
  let outer_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [
      nested,
      @ir.hot_build_drop(func, @ir.hot_build_const_i32(func, @lib.I32(11))),
      @ir.hot_build_drop(func, @ir.hot_build_const_i32(func, @lib.I32(12))),
    ],
    else_body=Some([
      @ir.hot_build_drop(func, @ir.hot_build_const_i32(func, @lib.I32(13))),
      @ir.hot_build_drop(func, @ir.hot_build_const_i32(func, @lib.I32(14))),
    ]),
  )
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, carrier), [
    outer_if,
    @ir.hot_build_const_i32(func, @lib.I32(1)),
  ])
  @ir.hot_root_append(func, carrier)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions escaping-if-arm cleanup success, got \{err}",
      )
  }

  let then_region = @ir.hot_region_then_ref(func, outer_if)
  @debug.assert_eq(@ir.hot_region_root_count(func, then_region), 1)
  let tail = @ir.hot_region_get(func, then_region, 0)
  match @ir.hot_node_get(func, tail).op {
    @ir.HotOp::If => ()
    _ =>
      fail(
        "expected escaping if arms to drop dead tails without a synthetic unreachable",
      )
  }
}

///|
test "optimize-instructions inverts nested boolean if conditions with live else arms" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i64 i32) (result i32) local.get 0 i64.eqz if (result i32) local.get 1 i32.eqz else i32.const 0 end if (result i32) i32.const 1 else local.get 0 i64.const -1 i64.eq if (result i32) local.get 1 else i32.const 0 end end))",
  )
  let outer_if = @ir.hot_root_get(func, 0)
  let outer_cond = @ir.hot_child_get(func, outer_if, 0)
  match @ir.hot_node_get(func, outer_if).op {
    @ir.HotOp::If => ()
    _ => fail("expected root to remain an if")
  }
  match @ir.hot_node_get(func, outer_cond).op {
    @ir.HotOp::If => ()
    _ => fail("expected outer condition to remain a nested if")
  }
  let inner_then = @ir.hot_region_then_ref(func, outer_cond)
  let inner_else = match @ir.hot_region_else_ref(func, outer_cond) {
    Some(region) => region
    None => fail("expected nested if condition to keep an else region")
  }
  let inner_then_root = @ir.hot_region_get(func, inner_then, 0)
  let inner_else_root = @ir.hot_region_get(func, inner_else, 0)
  match @ir.hot_node_get(func, inner_then_root).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected nested then arm to negate i32.eqz into the raw operand")
  }
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, inner_else_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )
  let outer_then = @ir.hot_region_then_ref(func, outer_if)
  let outer_else = match @ir.hot_region_else_ref(func, outer_if) {
    Some(region) => region
    None => fail("expected outer if to keep an else region")
  }
  let outer_then_root = @ir.hot_region_get(func, outer_then, 0)
  let outer_else_root = @ir.hot_region_get(func, outer_else, 0)
  match @ir.hot_node_get(func, outer_then_root).op {
    @ir.HotOp::If => ()
    _ => fail("expected outer then arm to become the flipped nested branch")
  }
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, outer_else_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )
}

///|
test "optimize-instructions wraps then-only nested boolean if conditions in eqz" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) local.get 0 if (result i32) local.get 1 i32.eqz else i32.const 0 end if local.get 1 drop end i32.const 0))",
  )
  let outer_if = @ir.hot_root_get(func, 0)
  let outer_cond = @ir.hot_child_get(func, outer_if, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, outer_cond),
    Some(@lib.Instruction::i32_eqz()),
  )
  let nested_if = @ir.hot_child_get(func, outer_cond, 0)
  match @ir.hot_node_get(func, nested_if).op {
    @ir.HotOp::If => ()
    _ => fail("expected eqz wrapper child to remain a nested if")
  }
  let inner_then = @ir.hot_region_then_ref(func, nested_if)
  let inner_else = match @ir.hot_region_else_ref(func, nested_if) {
    Some(region) => region
    None => fail("expected nested if condition to keep an else region")
  }
  let inner_then_root = @ir.hot_region_get(func, inner_then, 0)
  let inner_else_root = @ir.hot_region_get(func, inner_else, 0)
  match @ir.hot_node_get(func, inner_then_root).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected nested then arm to negate i32.eqz into the raw operand")
  }
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, inner_else_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )
}

///|
test "optimize-instructions recursively negates then-only nested boolean if conditions" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32 i32 i32) (result i32) local.get 0 if (result i32) local.get 1 if (result i32) i32.const 0 else local.get 2 if (result i32) i32.const 0 else local.get 3 i32.eqz end end else i32.const 0 end if local.get 1 drop end i32.const 0))",
  )
  let outer_if = @ir.hot_root_get(func, 0)
  let outer_cond = @ir.hot_child_get(func, outer_if, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, outer_cond),
    Some(@lib.Instruction::i32_eqz()),
  )
  let top_if = @ir.hot_child_get(func, outer_cond, 0)
  match @ir.hot_node_get(func, top_if).op {
    @ir.HotOp::If => ()
    _ => fail("expected outer eqz wrapper child to remain a nested if")
  }
  let top_then = @ir.hot_region_then_ref(func, top_if)
  let top_else = match @ir.hot_region_else_ref(func, top_if) {
    Some(region) => region
    None => fail("expected top nested if to keep an else region")
  }
  let top_then_root = @ir.hot_region_get(func, top_then, 0)
  let top_else_root = @ir.hot_region_get(func, top_else, 0)
  match @ir.hot_node_get(func, top_then_root).op {
    @ir.HotOp::If => ()
    _ =>
      fail(
        "expected recursive negation to keep the nested boolean tree in the then arm",
      )
  }
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, top_else_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )
  let inner_if = top_then_root
  let inner_then = @ir.hot_region_then_ref(func, inner_if)
  let inner_else = match @ir.hot_region_else_ref(func, inner_if) {
    Some(region) => region
    None => fail("expected inner nested if to keep an else region")
  }
  @debug.assert_eq(
    @ir.hot_const_get(
      func,
      @ir.hot_node_get(func, @ir.hot_region_get(func, inner_then, 0)).imm0,
    ),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )
  let inner_else_root = @ir.hot_region_get(func, inner_else, 0)
  match @ir.hot_node_get(func, inner_else_root).op {
    @ir.HotOp::If => ()
    _ =>
      fail("expected inner else arm to remain the nested recursive boolean if")
  }
}

///|
test "optimize-instructions skips nested-if condition rewrites when the condition value is shared" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32 i32 i32 i32) (result i32) local.get 0 if (result i32) local.get 1 if (result i32) i32.const 0 else local.get 2 if (result i32) i32.const 0 else local.get 3 i32.eqz end end else i32.const 0 end if local.get 1 drop end i32.const 0))",
  )
  let outer_if = @ir.hot_root_get(func, 0)
  let cond_id = @ir.hot_child_get(func, outer_if, 0)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, cond_id))
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions shared nested-if success, got \{err}",
      )
  }

  let shared_cond = @ir.hot_child_get(func, outer_if, 0)
  match @ir.hot_node_get(func, shared_cond).op {
    @ir.HotOp::If => ()
    _ => fail("expected shared nested if condition to stay unwrapped")
  }
  let lowered = @ir.hot_lower_func(func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [
                @lib.ValType::i32(),
                @lib.ValType::i32(),
                @lib.ValType::i32(),
                @lib.ValType::i32(),
              ],
              [@lib.ValType::i32()],
            ),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(if I32"), msg=pretty)
}

///|
test "optimize-instructions truncates dead suffixes after direct returns" {
  let func = @ir.HotFunc::new()
  let block = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, block), [
    @ir.hot_build_return(func, []),
    @ir.hot_build_const_i32(func, @lib.I32(0)),
  ])
  @ir.hot_root_append(func, block)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions direct-return dead-suffix cleanup success, got \{err}",
      )
  }

  let body = @ir.hot_region_body_ref(func, block)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 1)
  match @ir.hot_node_get(func, @ir.hot_region_get(func, body, 0)).op {
    @ir.HotOp::Return => ()
    _ => fail("expected dead roots after return to be truncated")
  }
}

///|
test "optimize-instructions keeps unreachable sentinels after looped escaping if ladders" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func (param i32) (result i32) local.get 0) (func (param i32 i32) (result i32) (local i32) local.get 0 call 0 local.get 1 call 0 i32.eq if loop local.get 0 call 0 local.get 2 i32.gt_s if local.get 0 local.get 2 i32.const 1 i32.shl i32.add i32.load16_u offset=8 local.get 1 local.get 2 i32.const 1 i32.shl i32.add i32.load16_u offset=8 i32.eq if local.get 2 i32.const 1 i32.add local.set 2 br 2 else i32.const 0 return end unreachable else i32.const 1 return end unreachable end unreachable else i32.const 0 return end unreachable))",
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected optimize-instructions looped escaping-if sentinel success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("(loop (Void)"), msg=pretty)
  @debug.assert_eq(
    optimize_instructions_test_count_substring(pretty, "unreachable"),
    4,
    msg=pretty,
  )
  assert_true(pretty.contains("(br (Label 2))"), msg=pretty)
}

///|
test "optimize-instructions keeps leading commutative constants in place" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) i32.const 7 local.get 0 i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  let lhs_node = @ir.hot_node_get(func, lhs)
  match lhs_node.op {
    @ir.HotOp::Const => ()
    _ => fail("expected leading commutative constant to stay on the lhs")
  }
  @debug.assert_eq(
    @ir.hot_const_get(func, lhs_node.imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(7)),
  )
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected non-constant commutative operand to stay on the rhs")
  }
}

///|
test "optimize-instructions rewrites i32.mul by a power of two into shl" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 8 i32.mul))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_shl()),
  )
  let rhs = @ir.hot_child_get(func, root, 1)
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(3)),
  )
}

///|
test "optimize-instructions keeps leading i64.mul const without commutative rewrite" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i64) i64.const 4 local.get 0 i64.mul))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i64_mul()),
  )
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::Const => ()
    _ => fail("expected leading i64.mul const to stay on the lhs")
  }
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, lhs).imm0),
    @ir.HotConstPayload::i64_const(@lib.I64(4L)),
  )
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected i64.mul local operand to stay on the rhs")
  }
}

///|
test "optimize-instructions folds exact i32 const adds" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (result i32) i32.const 249384 i32.const 15 i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected exact const add to fold into a const node")
  }
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(249399)),
  )
}

///|
test "optimize-instructions folds exact i32 const adds under and" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (result i32) i32.const 249384 i32.const 15 i32.add i32.const -16 i32.and))",
  )
  let root = @ir.hot_root_get(func, 0)
  let lhs = @ir.hot_child_get(func, root, 0)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::Const => ()
    _ => fail("expected const-add child to fold before the enclosing and")
  }
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, lhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(249399)),
  )
}

///|
test "optimize-instructions keeps tlsf-style base local before shifted offset" {
  let func = optimize_instructions_test_run_hot(
    "(module (memory 1) (func (param i32 i32) (result i32) (local i32 i32 i32 i32) local.get 1 i32.load align=1 i32.const -4 i32.and local.tee 2 i32.const 256 i32.lt_u if (result i32) local.get 2 i32.const 4 i32.shr_u local.set 3 i32.const 0 else i32.const 31 local.get 2 i32.const 1073741820 local.get 2 i32.const 1073741820 i32.ge_u select local.tee 3 i32.clz i32.sub local.set 2 local.get 3 local.get 2 i32.const 4 i32.sub i32.shr_u i32.const 16 i32.xor local.set 3 local.get 2 i32.const 7 i32.sub end local.set 5 local.get 1 local.get 0 local.get 5 i32.const 4 i32.shl local.get 3 i32.add i32.const 2 i32.shl i32.add local.tee 4 i32.load offset=96 align=1 i32.eq))",
  )
  let root = @ir.hot_root_get(func, func.roots.length() - 1)
  let first = @ir.hot_child_get(func, root, 0)
  let second = @ir.hot_child_get(func, root, 1)
  let load = match @ir.hot_node_get(func, first).op {
    @ir.HotOp::Load => first
    _ =>
      match @ir.hot_node_get(func, second).op {
        @ir.HotOp::Load => second
        _ => fail("expected compare root to keep one load child")
      }
  }
  let load_addr = @ir.hot_child_get(func, load, 0)
  let top_add = @ir.hot_child_get(func, load_addr, 0)
  let top_lhs = @ir.hot_child_get(func, top_add, 0)
  let top_rhs = @ir.hot_child_get(func, top_add, 1)
  match @ir.hot_node_get(func, top_lhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected tlsf-style base local term to stay on the lhs")
  }
  @debug.assert_eq(@ir.hot_node_get(func, top_lhs).imm0, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, top_rhs),
    Some(@lib.Instruction::i32_shl()),
  )
}

///|
test "optimize-instructions keeps lhs local before shifted local state" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) (local i32) local.get 0 local.get 1 local.tee 2 i32.const 1 i32.shl i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_add()),
  )
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  let lhs_node = @ir.hot_node_get(func, lhs)
  match lhs_node.op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected base local.get to stay before shifted local state")
  }
  @debug.assert_eq(lhs_node.imm0, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, rhs),
    Some(@lib.Instruction::i32_shl()),
  )
}

///|
test "optimize-instructions keeps shifted lhs before rhs local get" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) local.get 1 i32.const 1 i32.shl local.get 0 i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, lhs),
    Some(@lib.Instruction::i32_shl()),
  )
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected rhs local.get to stay behind shifted lhs")
  }
  @debug.assert_eq(@ir.hot_node_get(func, rhs).imm0, 0)
}

///|
test "optimize-instructions keeps local before shifted shared pure if leaves" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(
      params=[@lib.ValType::i32(), @lib.ValType::i32()],
      locals=[@lib.ValType::i32()],
    ),
  )
  let shared = @ir.hot_build_local_get(func, 1)
  let limit = @ir.hot_build_const_i32(func, @lib.I32(256))
  let cond = @ir.hot_build_compare(func, shared, limit)
  @ir.hot_node_exact_instr_set(func, cond, @lib.Instruction::i32_lt_u())
  let if_ = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    cond,
    [@ir.hot_build_const_i32(func, @lib.I32(0))],
    else_body=Some([shared]),
  )
  let tee = @ir.hot_build_local_tee(func, 2, if_)
  let shift = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    tee,
    @ir.hot_build_const_i32(func, @lib.I32(2)),
  )
  @ir.hot_node_exact_instr_set(func, shift, @lib.Instruction::i32_shl())
  let add = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    @ir.hot_build_local_get(func, 0),
    shift,
  )
  @ir.hot_node_exact_instr_set(func, add, @lib.Instruction::i32_add())
  @ir.hot_root_append(func, add)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected optimize-instructions shared-if success, got \{err}")
  }

  let lhs = @ir.hot_child_get(func, add, 0)
  let rhs = @ir.hot_child_get(func, add, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected plain local.get to stay before shifted shared-if lhs")
  }
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, rhs),
    Some(@lib.Instruction::i32_shl()),
  )
}

///|
test "optimize-instructions keeps local tee before rhs local get" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) (local i32 i32) local.get 0 local.tee 1 local.get 2 i32.eq))",
  )
  let root = @ir.hot_root_get(func, 0)
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::LocalTee => ()
    _ => fail("expected local.tee subtree to stay before rhs local.get")
  }
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected rhs local.get to stay behind local.tee")
  }
  @debug.assert_eq(@ir.hot_node_get(func, rhs).imm0, 2)
}

///|
test "optimize-instructions keeps commutative local get pair order" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32 i32) (result i32) local.get 2 local.get 1 i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::LocalGet => ()
    _ =>
      fail("expected lhs to stay a local.get after local-pair canonicalization")
  }
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::LocalGet => ()
    _ =>
      fail("expected rhs to stay a local.get after local-pair canonicalization")
  }
  @debug.assert_eq(@ir.hot_node_get(func, lhs).imm0, 2)
  @debug.assert_eq(@ir.hot_node_get(func, rhs).imm0, 1)
}

///|
test "optimize-instructions canonicalizes relational local gets after calls when crossing is safe" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32 i32) (result i32) local.get 2 local.get 0 local.get 1 local.get 2 call 0 i32.lt_s))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_gt_s()),
  )
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::Call => ()
    _ => fail("expected call subtree to move to relational lhs")
  }
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected local.get to move to relational rhs")
  }
  @debug.assert_eq(@ir.hot_node_get(func, rhs).imm0, 2)
}

///|
test "optimize-instructions strips if i32.ne x 0 conditions to the raw operand" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) (if (result i32) (i32.ne (local.get 1) (i32.const 0)) (then (i32.const 1)) (else (i32.const 0)))))",
  )
  let root = @ir.hot_root_get(func, 0)
  let cond = @ir.hot_child_get(func, root, 0)
  match @ir.hot_node_get(func, cond).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected i32.ne x 0 condition to simplify to the operand")
  }
}

///|
test "optimize-instructions flips if i32.eqz conditions with live else arms" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) (if (result i32) (i32.eqz (local.get 0)) (then (local.get 1)) (else (i32.const 7)))))",
  )
  let root = @ir.hot_root_get(func, 0)
  let cond = @ir.hot_child_get(func, root, 0)
  match @ir.hot_node_get(func, cond).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected i32.eqz condition to simplify to the operand")
  }
  let then_region = @ir.hot_region_then_ref(func, root)
  let else_region = @ir.hot_region_else_ref(func, root).unwrap()
  let then_root = @ir.hot_region_get(func, then_region, 0)
  let else_root = @ir.hot_region_get(func, else_region, 0)
  match @ir.hot_node_get(func, then_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected then arm to flip to the original else payload")
  }
  match @ir.hot_node_get(func, else_root).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected else arm to flip to the original then payload")
  }
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, then_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(7)),
  )
}

///|
test "optimize-instructions keeps pure multi-root constant-if chosen regions" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (result i32) i32.const 1 if (result i32) i32.const 2 drop i32.const 3 else i32.const 4 end))",
  )
  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::If => ()
    other =>
      fail(
        "expected pure multi-root constant if to stay structured, got \{other}",
      )
  }
  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected pure multi-root constant if to keep label owners valid, got \{err}",
      )
  }
}

///|
test "optimize-instructions keeps multi-root constant-if chosen regions" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 0 if (result i32) i32.const 1 else i32.const 2 local.set 0 i32.const 3 end))",
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected optimize-instructions multi-root constant if success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
}

///|
test "optimize-instructions keeps zero eqz if conditions unflipped" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (result i32) (if (result i32) (i32.eqz (i32.const 0)) (then (i32.const 1)) (else (i32.const 2)))))",
  )
  let root = @ir.hot_root_get(func, 0)
  let cond = @ir.hot_child_get(func, root, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, cond),
    Some(@lib.Instruction::i32_eqz()),
  )
}

///|
test "optimize-instructions keeps i64.eq zero if conditions in compare form" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i64 i64 i32) (result i32) local.get 2 if (result i32) local.get 0 i64.const 0 i64.eq if (result i32) i32.const 1 else local.get 0 local.get 1 i64.gt_u end else i32.const 1 end))",
  )
  let outer_if = @ir.hot_root_get(func, 0)
  let then_region = @ir.hot_region_then_ref(func, outer_if)
  let inner_if = @ir.hot_region_get(func, then_region, 0)
  let inner_cond = @ir.hot_child_get(func, inner_if, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, inner_cond),
    Some(@lib.Instruction::i64_eq()),
  )
}

///|
test "optimize-instructions wraps boolean value ifs in eqz at unique child uses" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) (local i32) local.get 0 if (result i32) local.get 1 i32.eqz else i32.const 0 end local.set 2 local.get 2))",
  )
  let set_ = @ir.hot_root_get(func, 0)
  let wrapped = @ir.hot_child_get(func, set_, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, wrapped),
    Some(@lib.Instruction::i32_eqz()),
  )
  let nested_if = @ir.hot_child_get(func, wrapped, 0)
  match @ir.hot_node_get(func, nested_if).op {
    @ir.HotOp::If => ()
    _ => fail("expected wrapped value rewrite to preserve the nested if")
  }
  let then_region = @ir.hot_region_then_ref(func, nested_if)
  let else_region = match @ir.hot_region_else_ref(func, nested_if) {
    Some(region) => region
    None => fail("expected wrapped value if to keep an else region")
  }
  let then_root = @ir.hot_region_get(func, then_region, 0)
  let else_root = @ir.hot_region_get(func, else_region, 0)
  match @ir.hot_node_get(func, then_root).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected wrapped value if then arm to expose the local")
  }
  @debug.assert_eq(@ir.hot_node_get(func, then_root).imm0, 1)
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, else_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )
}

///|
test "optimize-instructions keeps boolean value ifs unwrapped when they feed if conditions" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32 i32) (result i32) local.get 0 if (result i32) local.get 1 if (result i32) local.get 2 i32.eqz else i32.const 0 end else i32.const 0 end if (result i32) i32.const 7 else i32.const 8 end))",
  )
  let outer_if = @ir.hot_root_get(func, 0)
  let outer_cond = @ir.hot_child_get(func, outer_if, 0)
  match @ir.hot_node_get(func, outer_cond).op {
    @ir.HotOp::If => ()
    _ => fail("expected outer if condition to remain the nested boolean if")
  }
  let outer_then = @ir.hot_region_then_ref(func, outer_if)
  let outer_else = match @ir.hot_region_else_ref(func, outer_if) {
    Some(region) => region
    None => fail("expected outer if to keep an else region")
  }
  let then_root = @ir.hot_region_get(func, outer_then, 0)
  let else_root = @ir.hot_region_get(func, outer_else, 0)
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, then_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(7)),
  )
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, else_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(8)),
  )
  let cond_then = @ir.hot_region_then_ref(func, outer_cond)
  let cond_then_root = @ir.hot_region_get(func, cond_then, 0)
  match @ir.hot_node_get(func, cond_then_root).op {
    @ir.HotOp::If => ()
    _ => fail("expected nested boolean then arm to stay as the inner if")
  }
}

///|
test "optimize-instructions keeps boolean value ifs unwrapped in branch payloads" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) block (result i32) local.get 0 if (result i32) i32.const 1 else i32.const 0 end br 0 end))",
  )
  let block = @ir.hot_root_get(func, 0)
  let body = @ir.hot_region_body_ref(func, block)
  let branch = @ir.hot_region_get(func, body, 0)
  let payload = @ir.hot_child_get(func, branch, 0)
  match @ir.hot_node_get(func, payload).op {
    @ir.HotOp::If => ()
    _ => fail("expected branch payload to stay as the original value if")
  }
}

///|
test "optimize-instructions keeps trivial boolean value ifs unwrapped in local sets" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) (local i32) local.get 0 if (result i32) i32.const 0 else i32.const 1 end local.set 1 local.get 1))",
  )
  let set_ = @ir.hot_root_get(func, 0)
  let payload = @ir.hot_child_get(func, set_, 0)
  match @ir.hot_node_get(func, payload).op {
    @ir.HotOp::If => ()
    _ =>
      fail(
        "expected trivial boolean local-set payload to stay as the original if",
      )
  }
}

///|
test "optimize-instructions keeps constant boolean decision trees unwrapped in local sets" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) (local i32) local.get 0 if (result i32) i32.const 1 else local.get 1 if (result i32) i32.const 1 else i32.const 0 end end local.set 2 local.get 2))",
  )
  let set_ = @ir.hot_root_get(func, 0)
  let payload = @ir.hot_child_get(func, set_, 0)
  match @ir.hot_node_get(func, payload).op {
    @ir.HotOp::If => ()
    _ =>
      fail(
        "expected constant boolean local-set decision tree to stay as the original if",
      )
  }
}

///|
test "optimize-instructions keeps zero sentinels after returning ifs in result blocks" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) (block (result i32) (if (result i32) (local.get 0) (then (block (return (i32.const 1)))) (else (block (return (i32.const 0))))) (i32.const 0))))",
  )
  let block = @ir.hot_root_get(func, 0)
  let body = @ir.hot_region_body_ref(func, block)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 2)
  let tail = @ir.hot_region_get(func, body, 1)
  match @ir.hot_node_get(func, tail).op {
    @ir.HotOp::Const => ()
    _ =>
      fail(
        "expected result-block zero sentinel to stay explicit after a returning if",
      )
  }
}

///|
test "optimize-instructions keeps zero sentinels after wrapped returning ifs in result blocks" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) (block (result i32) (block (result i32) (if (result i32) (local.get 0) (then (block (return (i32.const 1)))) (else (block (return (i32.const 0))))) (i32.const 0)))))",
  )
  let outer = @ir.hot_root_get(func, 0)
  let outer_body = @ir.hot_region_body_ref(func, outer)
  let inner = @ir.hot_region_get(func, outer_body, 0)
  let inner_body = @ir.hot_region_body_ref(func, inner)
  @debug.assert_eq(@ir.hot_region_root_count(func, inner_body), 2)
  let tail = @ir.hot_region_get(func, inner_body, 1)
  match @ir.hot_node_get(func, tail).op {
    @ir.HotOp::Const => ()
    _ =>
      fail(
        "expected wrapped result-block zero sentinel to stay explicit after a returning if",
      )
  }
}

///|
test "optimize-instructions keeps zero sentinels after returning ifs with dead arm suffixes" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) (block (result i32) (if (local.get 0) (then (return (i32.const 1)) (i32.const 9)) (else (return (i32.const 0)) (i32.const 8))) (i32.const 0))))",
  )
  let block = @ir.hot_root_get(func, 0)
  let body = @ir.hot_region_body_ref(func, block)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 2)
  let tail = @ir.hot_region_get(func, body, 1)
  match @ir.hot_node_get(func, tail).op {
    @ir.HotOp::Const => ()
    _ =>
      fail(
        "expected result-block zero sentinel to stay explicit when if arms end in dead suffixes",
      )
  }
}

///|
test "optimize-instructions keeps wrapped local.set prefixes void when child exits still target the parent" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (param i32 i32) (result i32) (local i32) (block $outer (block $mid (local.get 0) (i32.const 0) (i32.eq) (if (then (br $outer)) (else (local.get 1) (if (then (i32.const 7) (local.set 2) (br $mid)) (else (br $outer))) unreachable)) unreachable) (local.get 2) (local.set 1) (local.get 1) return) (i32.const 0))))",
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected optimize-instructions mixed-depth local.set prefix success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("(local.set (Local 1))"), msg=pretty)
  assert_true(pretty.contains("(local.get (Local 2))"), msg=pretty)
  assert_false(pretty.contains("(block (I32)"), msg=pretty)
}

///|
test "optimize-instructions does not reorder across the same local" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 local.get 0 local.tee 0 i32.const 1 i32.shl i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  let lhs = @ir.hot_child_get(func, root, 0)
  let lhs_node = @ir.hot_node_get(func, lhs)
  match lhs_node.op {
    @ir.HotOp::LocalGet => ()
    _ =>
      fail(
        "expected same-local read to stay ahead of a conflicting tee subtree",
      )
  }
  @debug.assert_eq(lhs_node.imm0, 0)
}

///|
test "optimize-instructions keeps local get before trapping load" {
  let func = optimize_instructions_test_run_hot(
    "(module (memory 1) (func (param i32 i32) (result i32) local.get 0 local.get 1 i32.load i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected local.get to stay before trapping load subtree")
  }
  @debug.assert_eq(@ir.hot_node_get(func, lhs).imm0, 0)
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::Load => ()
    _ => fail("expected trapping load subtree to stay on the rhs")
  }
}

///|
test "optimize-instructions removes redundant shift masks" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) local.get 0 local.get 1 i32.const 31 i32.and i32.shl))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_shl()),
  )
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected redundant shift mask to collapse to the masked operand")
  }
}

///|
test "optimize-instructions removes effective zero shifts" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 32 i32.shl))",
  )
  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected effective zero shift to become its lhs operand")
  }
}

///|
test "optimize-instructions canonicalizes non-negative signed const ops to unsigned" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (result i32) i32.const 84 i32.const 3 i32.div_s))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_div_u()),
  )

  let compare_func = optimize_instructions_test_run_hot(
    "(module (func (result i32) i32.const 11 i32.const 3 i32.lt_s))",
  )
  let compare_root = @ir.hot_root_get(compare_func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(compare_func, compare_root),
    Some(@lib.Instruction::i32_lt_u()),
  )
}

///|
test "optimize-instructions keeps signed ops with negative constants signed" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (result i32) i32.const -84 i32.const 3 i32.div_s))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_div_s()),
  )
}

///|
test "optimize-instructions folds unsigned ge zero on pure values" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 0 i32.ge_u))",
  )
  let root = @ir.hot_root_get(func, 0)
  let root_node = @ir.hot_node_get(func, root)
  match root_node.op {
    @ir.HotOp::Const => ()
    _ => fail("expected unsigned ge zero to fold to a const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(func, root_node.imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )
}

///|
test "optimize-instructions canonicalizes relational constants onto the rhs" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) i32.const 9 local.get 0 i32.gt_u))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_lt_u()),
  )
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected non-constant compare operand on the lhs")
  }
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(9)),
  )
}

///|
test "optimize-instructions canonicalizes unsigned compare-to-one" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 1 i32.lt_u))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_eq()),
  )
  let rhs = @ir.hot_child_get(func, root, 1)
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )
}

///|
test "optimize-instructions canonicalizes signed compare to zero" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 1 i32.ge_s))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i32_gt_s()),
  )
  let rhs = @ir.hot_child_get(func, root, 1)
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )
}

///|
test "optimize-instructions does not reorder relational operands across shared tee payloads" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  let shared = @ir.hot_build_local_get(func, 1)
  let tee = @ir.hot_build_local_tee(func, 2, shared)
  let limit = @ir.hot_build_local_get(func, 0)
  let compare = @ir.hot_build_compare(func, tee, limit)
  @ir.hot_node_exact_instr_set(func, compare, @lib.Instruction::i32_lt_s())
  @ir.hot_root_append(func, compare)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared))
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected optimize-instructions shared-tee success, got \{err}")
  }

  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, compare),
    Some(@lib.Instruction::i32_lt_s()),
  )
  match @ir.hot_node_get(func, @ir.hot_child_get(func, compare, 0)).op {
    @ir.HotOp::LocalTee => ()
    _ => fail("expected shared tee subtree to stay on the lhs")
  }
  let lowered = @ir.hot_lower_func(func)
  let @lib.Func(locals, body) = lowered
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(
    body,
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::i32_lt_s(),
      @lib.Instruction::drop(),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::drop(),
    ]),
  )
}

///|
test "optimize-instructions does not allocate scratch locals for shared relational tee payloads in blocks" {
  let fixture = @ir.ir_test_build_hot_from_wat(
    "(module (func (param i32) (result i32) (local i32 i32) i32.const 0 local.set 1 loop $label2 block $block5 block $block4 (result i32) local.get 1 local.tee 2 local.get 0 i32.lt_s if local.get 2 i32.const 1 i32.add br $block4 end br $block5 end local.set 1 end br $label2 end local.get 1))",
  )
  let func = fixture.hot_func
  let loop_id = @ir.hot_root_get(func, 1)
  let block5 = @ir.hot_region_get(
    func,
    @ir.hot_region_body_ref(func, loop_id),
    0,
  )
  let set1 = @ir.hot_region_get(func, @ir.hot_region_body_ref(func, block5), 0)
  let block4 = @ir.hot_child_get(func, set1, 0)
  let block4_body = @ir.hot_region_body_ref(func, block4)
  let if_id = @ir.hot_region_get(func, block4_body, 0)
  let branch = @ir.hot_region_get(func, block4_body, 1)
  let compare = @ir.hot_child_get(func, if_id, 0)
  let tee = @ir.hot_child_get(func, compare, 0)
  let shared = @ir.hot_child_get(func, tee, 0)
  @ir.hot_region_replace_body(func, block4_body, [
    if_id,
    @ir.hot_build_drop(func, shared),
    branch,
  ])
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected optimize-instructions shared-block success, got \{err}")
  }

  let lowered = @ir.hot_lower_func(func)
  let @lib.Func(locals, _) = lowered
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
}

///|
test "optimize-instructions does not allocate scratch locals for shared tee payload fallthroughs" {
  let fixture = @ir.ir_test_build_hot_from_wat(
    "(module (func (param i32) (result i32) (local i32 i32) i32.const 0 local.set 1 loop $label block $body (result i32) local.get 1 local.tee 2 local.get 0 i32.lt_s if local.get 2 i32.const 1 i32.add br $body end local.get 1 end local.set 1 br $label end unreachable))",
  )
  let func = fixture.hot_func
  let loop_id = @ir.hot_root_get(func, 1)
  let set1 = @ir.hot_region_get(func, @ir.hot_region_body_ref(func, loop_id), 0)
  let body = @ir.hot_child_get(func, set1, 0)
  let body_region = @ir.hot_region_body_ref(func, body)
  let if_id = @ir.hot_region_get(func, body_region, 0)
  let compare = @ir.hot_child_get(func, if_id, 0)
  let tee = @ir.hot_child_get(func, compare, 0)
  let shared = @ir.hot_child_get(func, tee, 0)
  @ir.hot_region_replace_body(func, body_region, [if_id, shared])
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected optimize-instructions shared-fallthrough success, got \{err}",
      )
  }

  let lowered = @ir.hot_lower_func(func)
  let @lib.Func(locals, _) = lowered
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
}

///|
test "optimize-instructions does not reorder relational local gets across control-bearing tee payloads" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ]),
  )
  let block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [],
  )
  let label = @ir.hot_control_node_label(func, block)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, block), [
    @ir.hot_build_br(func, label, values=[
      @ir.hot_build_const_i32(func, @lib.I32(7)),
    ]),
  ])
  let tee = @ir.hot_build_local_tee(func, 2, block)
  let limit = @ir.hot_build_local_get(func, 0)
  let compare = @ir.hot_build_compare(func, tee, limit)
  @ir.hot_node_exact_instr_set(func, compare, @lib.Instruction::i32_lt_s())
  @ir.hot_root_append(func, @ir.hot_build_drop(func, compare))
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected optimize-instructions control-tee success, got \{err}")
  }

  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, compare),
    Some(@lib.Instruction::i32_lt_s()),
  )
  match @ir.hot_node_get(func, @ir.hot_child_get(func, compare, 0)).op {
    @ir.HotOp::LocalTee => ()
    _ => fail("expected control-bearing tee subtree to stay on the lhs")
  }
}

///|
test "optimize-instructions does not reorder relational local gets across loop-carried tees" {
  let fixture = @ir.ir_test_build_hot_from_wat(
    "(module (func (param i32) (result i32) (local i32) (block (result i32) (i32.const 0) (loop (param i32) (result i32) (if (result i32) (i32.lt_s (local.tee 1) (local.get 0)) (then (local.get 1) (i32.const 1) (i32.add) (br 1)) (else (local.get 1)))))))",
  )
  let func = fixture.hot_func
  let block_id = @ir.hot_root_get(func, 0)
  let block_body = @ir.hot_region_body_ref(func, block_id)
  let loop_id = @ir.hot_region_get(func, block_body, 0)
  let body_region = @ir.hot_region_body_ref(func, loop_id)
  let if_id = @ir.hot_region_get(func, body_region, 0)
  let compare = @ir.hot_child_get(func, if_id, 0)
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected optimize-instructions loop-carried success, got \{err}")
  }

  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, compare),
    Some(@lib.Instruction::i32_lt_s()),
  )
  match @ir.hot_node_get(func, @ir.hot_child_get(func, compare, 0)).op {
    @ir.HotOp::LocalTee => ()
    _ => fail("expected loop-carried tee subtree to stay on the lhs")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, compare, 1)).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected loop-carried limit local.get to stay on the rhs")
  }
}

///|
test "optimize-instructions visits shared dags once" {
  let func = optimize_instructions_shared_dag_fixture(24)
  let node_count = @ir.hot_node_count(func)
  let perf = HotPerfSession::new()
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    perf=Some(perf),
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected optimize-instructions shared-dag success, got \{err}")
  }

  let counters = perf_counters(perf)
  @debug.assert_eq(counters.traversal_visits, node_count)
}
