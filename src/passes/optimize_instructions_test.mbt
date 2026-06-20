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
fn optimize_instructions_test_run_module(mod_ : @lib.Module) -> @lib.Module {
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) =>
      abort("unexpected invalid optimize-instructions fixture: \{err}")
  }
  match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      abort("expected optimize-instructions pipeline success, got \{err}")
  }
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
test "optimize-instructions intentionally keeps load-call memory offset folds behind raw gate" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (import "m" "touch" (func $touch))
        #|  (memory 1)
        #|  (func
        #|    i32.const 8
        #|    i32.load offset=4
        #|    drop
        #|    call $touch))
        #|,
      ),
      ["optimize-instructions"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected load-call memory offset gate success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[optimize-instructions]:skip-raw reason=load-call-optimize-instructions-noop",
      )
    }),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  // Intentional fail-closed OI-G boundary: the direct HOT pass can fold
  // constant-pointer static offsets, but the public pipeline keeps mixed
  // load/call functions unchanged until the raw gate has a narrower,
  // source-backed escape proof.
  assert_true(pretty.contains("i32.const I32(8)"), msg=pretty)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("offset=U64(4)"), msg=pretty)
  assert_false(pretty.contains("i32.const I32(12)"), msg=pretty)
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
test "optimize-instructions folds ref.is_null on known null refs" {
  let source =
    #|(module
    #|  (func (export "null") (result i32)
    #|    ref.null func
    #|    ref.is_null)
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ref.is_null optimize success, got \{err}")
  }
  let null_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(null_pretty.contains("ref.is_null"), msg=null_pretty)
  assert_true(null_pretty.contains("I32(1)"), msg=null_pretty)
}

///|
test "optimize-instructions folds ref.is_null on locally known non-null refs" {
  let source =
    #|(module
    #|  (func $callee)
    #|  (elem declare func $callee)
    #|  (func (export "i31") (result i32)
    #|    i32.const 7
    #|    ref.i31
    #|    ref.is_null)
    #|  (func (export "func") (result i32)
    #|    ref.func $callee
    #|    ref.is_null)
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected non-null ref.is_null optimize success, got \{err}")
  }
  let i31_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let func_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(i31_pretty.contains("ref.is_null"), msg=i31_pretty)
  assert_false(func_pretty.contains("ref.is_null"), msg=func_pretty)
  assert_true(i31_pretty.contains("I32(0)"), msg=i31_pretty)
  assert_true(func_pretty.contains("I32(0)"), msg=func_pretty)
}

///|
test "optimize-instructions folds reference checks on non-null local refs" {
  let source =
    #|(module
    #|  (func (export "is-null") (param (ref eq)) (result i32)
    #|    local.get 0
    #|    ref.is_null)
    #|  (func (export "as-non-null") (param (ref eq)) (result (ref eq))
    #|    local.get 0
    #|    ref.as_non_null)
    #|  (func (export "eq-null") (param (ref eq)) (result i32)
    #|    local.get 0
    #|    ref.null eq
    #|    ref.eq)
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected non-null local ref optimize success, got \{err}")
  }
  let is_null_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let as_non_null_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let eq_null_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(is_null_pretty.contains("ref.is_null"), msg=is_null_pretty)
  assert_true(is_null_pretty.contains("I32(0)"), msg=is_null_pretty)
  assert_false(
    as_non_null_pretty.contains("ref.as_non_null"),
    msg=as_non_null_pretty,
  )
  assert_true(as_non_null_pretty.contains("local.get"), msg=as_non_null_pretty)
  assert_false(eq_null_pretty.contains("ref.eq"), msg=eq_null_pretty)
  assert_true(eq_null_pretty.contains("I32(0)"), msg=eq_null_pretty)
}

///|
test "optimize-instructions folds null equality against locally known non-null refs" {
  let source =
    #|(module
    #|  (func (export "i31-right-null") (result i32)
    #|    i32.const 7
    #|    ref.i31
    #|    ref.null eq
    #|    ref.eq)
    #|  (func (export "null-i31") (result i32)
    #|    ref.null eq
    #|    i32.const 7
    #|    ref.i31
    #|    ref.eq)
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected known non-null ref.eq optimize success, got \{err}")
  }
  let right_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let left_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(right_pretty.contains("ref.eq"), msg=right_pretty)
  assert_false(left_pretty.contains("ref.eq"), msg=left_pretty)
  assert_true(right_pretty.contains("I32(0)"), msg=right_pretty)
  assert_true(left_pretty.contains("I32(0)"), msg=left_pretty)
}

///|
test "optimize-instructions folds equality on local ref.i31 constants" {
  let source =
    #|(module
    #|  (func (export "same") (result i32)
    #|    i32.const 7
    #|    ref.i31
    #|    i32.const 7
    #|    ref.i31
    #|    ref.eq)
    #|  (func (export "different") (result i32)
    #|    i32.const 7
    #|    ref.i31
    #|    i32.const 8
    #|    ref.i31
    #|    ref.eq)
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ref.i31 ref.eq optimize success, got \{err}")
  }
  let same_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let different_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(same_pretty.contains("ref.eq"), msg=same_pretty)
  assert_false(different_pretty.contains("ref.eq"), msg=different_pretty)
  assert_true(same_pretty.contains("I32(1)"), msg=same_pretty)
  assert_true(different_pretty.contains("I32(0)"), msg=different_pretty)
}

///|
test "optimize-instructions folds same-local ref.i31 equality" {
  let source =
    #|(module
    #|  (func (export "same-local-i31") (param i32) (result i32)
    #|    local.get 0
    #|    ref.i31
    #|    local.get 0
    #|    ref.i31
    #|    ref.eq)
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected same-local ref.i31 ref.eq optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("ref.eq"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
}

///|
test "optimize-instructions preserves trap while folding same-local nullable ref.as_non_null equality" {
  let source =
    #|(module
    #|  (func (export "left") (param eqref) (result i32)
    #|    local.get 0
    #|    ref.as_non_null
    #|    local.get 0
    #|    ref.eq)
    #|  (func (export "both") (param eqref) (result i32)
    #|    local.get 0
    #|    ref.as_non_null
    #|    local.get 0
    #|    ref.as_non_null
    #|    ref.eq)
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nullable ref.as_non_null same-local ref.eq optimize success, got \{err}",
      )
  }
  let left_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let both_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(left_pretty.contains("ref.eq"), msg=left_pretty)
  assert_false(both_pretty.contains("ref.eq"), msg=both_pretty)
  assert_true(left_pretty.contains("ref.as_non_null"), msg=left_pretty)
  assert_true(both_pretty.contains("ref.as_non_null"), msg=both_pretty)
  assert_true(left_pretty.contains("drop"), msg=left_pretty)
  assert_true(both_pretty.contains("drop"), msg=both_pretty)
  assert_true(left_pretty.contains("I32(1)"), msg=left_pretty)
  assert_true(both_pretty.contains("I32(1)"), msg=both_pretty)
}

///|
test "optimize-instructions folds same-local equality through nullable no-op ref.cast" {
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let eq_ref = @lib.ValType::ref_null(eq_heap)
  let i32_type = @lib.TypeIdx::new(0U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([eq_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([i32_type, i32_type, i32_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(true, eq_heap),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_eq(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(true, eq_heap),
            @lib.Instruction::ref_eq(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(true, eq_heap),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(true, eq_heap),
            @lib.Instruction::ref_eq(),
          ]),
        ),
      ]),
    ),
  )
  let left_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let right_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let both_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(left_pretty.contains("ref.eq"), msg=left_pretty)
  assert_false(right_pretty.contains("ref.eq"), msg=right_pretty)
  assert_false(both_pretty.contains("ref.eq"), msg=both_pretty)
  assert_true(left_pretty.contains("I32(1)"), msg=left_pretty)
  assert_true(right_pretty.contains("I32(1)"), msg=right_pretty)
  assert_true(both_pretty.contains("I32(1)"), msg=both_pretty)
}

///|
test "optimize-instructions folds same-local equality through nullable upcast ref.cast" {
  let struct_heap = @lib.HeapType::abs(@lib.AbsHeapType::struct_())
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let struct_ref = @lib.ValType::ref_null(struct_heap)
  let i32_type = @lib.TypeIdx::new(0U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([struct_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([i32_type, i32_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(true, eq_heap),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_eq(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(true, eq_heap),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(true, eq_heap),
            @lib.Instruction::ref_eq(),
          ]),
        ),
      ]),
    ),
  )
  let left_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let both_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(left_pretty.contains("ref.eq"), msg=left_pretty)
  assert_false(both_pretty.contains("ref.eq"), msg=both_pretty)
  assert_true(left_pretty.contains("I32(1)"), msg=left_pretty)
  assert_true(both_pretty.contains("I32(1)"), msg=both_pretty)
}

///|
test "optimize-instructions folds same-local i31 equality through nullable upcast ref.cast" {
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let i31_ref = @lib.ValType::ref_null(i31_heap)
  let i32_type = @lib.TypeIdx::new(0U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([i31_ref], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([i32_type, i32_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(true, eq_heap),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_eq(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(true, eq_heap),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(true, eq_heap),
            @lib.Instruction::ref_eq(),
          ]),
        ),
      ]),
    ),
  )
  let left_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let both_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(left_pretty.contains("ref.eq"), msg=left_pretty)
  assert_false(both_pretty.contains("ref.eq"), msg=both_pretty)
  assert_true(left_pretty.contains("I32(1)"), msg=left_pretty)
  assert_true(both_pretty.contains("I32(1)"), msg=both_pretty)
}

///|
test "optimize-instructions folds self equality on local refs" {
  let source =
    #|(module
    #|  (func (export "nullable") (param eqref) (result i32)
    #|    local.get 0
    #|    local.get 0
    #|    ref.eq)
    #|  (func (export "non-null") (param (ref eq)) (result i32)
    #|    local.get 0
    #|    local.get 0
    #|    ref.eq)
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local self ref.eq optimize success, got \{err}")
  }
  let nullable_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let non_null_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(nullable_pretty.contains("ref.eq"), msg=nullable_pretty)
  assert_false(non_null_pretty.contains("ref.eq"), msg=non_null_pretty)
  assert_true(nullable_pretty.contains("I32(1)"), msg=nullable_pretty)
  assert_true(non_null_pretty.contains("I32(1)"), msg=non_null_pretty)
}

///|
test "optimize-instructions folds impossible equality between i31 and struct locals" {
  let source =
    #|(module
    #|  (type $s (struct))
    #|  (func (export "right") (param (ref null $s)) (result i32)
    #|    i32.const 7
    #|    ref.i31
    #|    local.get 0
    #|    ref.eq)
    #|  (func (export "left") (param (ref i31)) (param (ref null $s)) (result i32)
    #|    local.get 1
    #|    local.get 0
    #|    ref.eq)
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected impossible i31/struct ref.eq optimize success, got \{err}")
  }
  let right_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let left_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(right_pretty.contains("ref.eq"), msg=right_pretty)
  assert_false(left_pretty.contains("ref.eq"), msg=left_pretty)
  assert_true(right_pretty.contains("I32(0)"), msg=right_pretty)
  assert_true(left_pretty.contains("I32(0)"), msg=left_pretty)
}

///|
test "optimize-instructions folds impossible equality between non-null struct and array locals" {
  let source =
    #|(module
    #|  (func (export "right") (param (ref struct)) (param (ref null array)) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    ref.eq)
    #|  (func (export "left") (param (ref null array)) (param (ref struct)) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    ref.eq)
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected impossible non-null struct/array ref.eq optimize success, got \{err}",
      )
  }
  let right_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let left_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(right_pretty.contains("ref.eq"), msg=right_pretty)
  assert_false(left_pretty.contains("ref.eq"), msg=left_pretty)
  assert_true(right_pretty.contains("I32(0)"), msg=right_pretty)
  assert_true(left_pretty.contains("I32(0)"), msg=left_pretty)
}

///|
test "optimize-instructions folds ref.as_non_null on known null and non-null refs" {
  let source =
    #|(module
    #|  (func $callee)
    #|  (elem declare func $callee)
    #|  (func (export "null") (result eqref)
    #|    ref.null eq
    #|    ref.as_non_null)
    #|  (func (export "i31") (result eqref)
    #|    i32.const 7
    #|    ref.i31
    #|    ref.as_non_null)
    #|  (func (export "func") (result funcref)
    #|    ref.func $callee
    #|    ref.as_non_null)
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ref.as_non_null optimize success, got \{err}")
  }
  let null_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let i31_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let func_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(null_pretty.contains("unreachable"), msg=null_pretty)
  assert_false(null_pretty.contains("ref.as_non_null"), msg=null_pretty)
  assert_true(i31_pretty.contains("ref.i31"), msg=i31_pretty)
  assert_false(i31_pretty.contains("ref.as_non_null"), msg=i31_pretty)
  assert_true(func_pretty.contains("ref.func"), msg=func_pretty)
  assert_false(func_pretty.contains("ref.as_non_null"), msg=func_pretty)
}

///|
test "optimize-instructions folds nullable ref.test and ref.cast on known null refs" {
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let eq_ref = @lib.ValType::ref_null(eq_heap)
  let i32_type = @lib.TypeIdx::new(0U)
  let eq_type = @lib.TypeIdx::new(1U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [eq_ref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([i32_type, eq_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::ref_null(eq_heap),
            @lib.Instruction::ref_test(true, eq_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::ref_null(eq_heap),
            @lib.Instruction::ref_cast(true, eq_heap),
          ]),
        ),
      ]),
    ),
  )
  let test_nullable = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let cast_nullable = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(test_nullable.contains("ref.test"), msg=test_nullable)
  assert_true(test_nullable.contains("I32(1)"), msg=test_nullable)
  assert_true(cast_nullable.contains("ref.null"), msg=cast_nullable)
  assert_false(cast_nullable.contains("ref.cast"), msg=cast_nullable)
}

///|
test "optimize-instructions folds non-null ref.test and ref.cast on known null refs" {
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let non_null_eq_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, eq_heap),
  )
  let i32_type = @lib.TypeIdx::new(0U)
  let eq_type = @lib.TypeIdx::new(1U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [non_null_eq_ref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([i32_type, eq_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::ref_null(eq_heap),
            @lib.Instruction::ref_test(false, eq_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::ref_null(eq_heap),
            @lib.Instruction::ref_cast(false, eq_heap),
          ]),
        ),
      ]),
    ),
  )
  let test_nonnull = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let cast_nonnull = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(test_nonnull.contains("ref.test"), msg=test_nonnull)
  assert_true(test_nonnull.contains("I32(0)"), msg=test_nonnull)
  assert_true(cast_nonnull.contains("unreachable"), msg=cast_nonnull)
  assert_false(cast_nonnull.contains("ref.cast"), msg=cast_nonnull)
}

///|
test "optimize-instructions folds successful ref.test and ref.cast on local i31 refs" {
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i32_type = @lib.TypeIdx::new(0U)
  let i31_type = @lib.TypeIdx::new(1U)
  let eq_type = @lib.TypeIdx::new(2U)
  let any_type = @lib.TypeIdx::new(3U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i31ref()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::eqref_null()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::anyref()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([
        i32_type, i31_type, i32_type, eq_type, i32_type, any_type,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::ref_i31(),
            @lib.Instruction::ref_test(false, i31_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::ref_i31(),
            @lib.Instruction::ref_cast(false, i31_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::ref_i31(),
            @lib.Instruction::ref_test(false, eq_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::ref_i31(),
            @lib.Instruction::ref_cast(false, eq_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::ref_i31(),
            @lib.Instruction::ref_test(false, any_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::ref_i31(),
            @lib.Instruction::ref_cast(false, any_heap),
          ]),
        ),
      ]),
    ),
  )
  let test_i31 = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let cast_i31 = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let test_eq = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let cast_eq = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  let test_any = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  let cast_any = optimized.pretty_print_func(@lib.FuncIdx::new(5U))
  assert_false(test_i31.contains("ref.test"), msg=test_i31)
  assert_true(test_i31.contains("I32(1)"), msg=test_i31)
  assert_true(cast_i31.contains("ref.i31"), msg=cast_i31)
  assert_false(cast_i31.contains("ref.cast"), msg=cast_i31)
  assert_false(test_eq.contains("ref.test"), msg=test_eq)
  assert_true(test_eq.contains("I32(1)"), msg=test_eq)
  assert_true(cast_eq.contains("ref.i31"), msg=cast_eq)
  assert_false(cast_eq.contains("ref.cast"), msg=cast_eq)
  assert_false(test_any.contains("ref.test"), msg=test_any)
  assert_true(test_any.contains("I32(1)"), msg=test_any)
  assert_true(cast_any.contains("ref.i31"), msg=cast_any)
  assert_false(cast_any.contains("ref.cast"), msg=cast_any)
}

///|
test "optimize-instructions preserves effectful ref.i31 operand for failed ref.test and ref.cast" {
  let effect_type = @lib.TypeIdx::new(0U)
  let test_type = @lib.TypeIdx::new(1U)
  let cast_type = @lib.TypeIdx::new(2U)
  let struct_heap = @lib.HeapType::abs(@lib.AbsHeapType::struct_())
  let struct_ref = @lib.ValType::ref_type(@lib.RefType::new(false, struct_heap))
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [struct_ref])),
        ),
      ]),
    )
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("m"),
          @lib.Name::from_string("effect"),
          @lib.ExternType::func(effect_type),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([test_type, cast_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::ref_i31(),
            @lib.Instruction::ref_test(false, struct_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::ref_i31(),
            @lib.Instruction::ref_cast(false, struct_heap),
          ]),
        ),
      ]),
    ),
  )
  let test_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let cast_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(test_pretty.contains("ref.test"), msg=test_pretty)
  assert_true(test_pretty.contains("call (Func 0)"), msg=test_pretty)
  assert_true(test_pretty.contains("drop"), msg=test_pretty)
  assert_true(test_pretty.contains("I32(0)"), msg=test_pretty)
  assert_false(cast_pretty.contains("ref.cast"), msg=cast_pretty)
  assert_true(cast_pretty.contains("call (Func 0)"), msg=cast_pretty)
  assert_true(cast_pretty.contains("drop"), msg=cast_pretty)
  assert_true(cast_pretty.contains("unreachable"), msg=cast_pretty)
}

///|
test "optimize-instructions preserves effectful ref.i31 operand for ref.is_null miss" {
  let effect_type = @lib.TypeIdx::new(0U)
  let i32_type = @lib.TypeIdx::new(1U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("m"),
          @lib.Name::from_string("effect"),
          @lib.ExternType::func(effect_type),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([i32_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::ref_i31(),
            @lib.Instruction::ref_is_null(),
          ]),
        ),
      ]),
    ),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("ref.is_null"), msg=pretty)
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("I32(0)"), msg=pretty)
}

///|
test "optimize-instructions preserves effectful ref.i31 operand for ref.eq null miss" {
  let effect_type = @lib.TypeIdx::new(0U)
  let i32_type = @lib.TypeIdx::new(1U)
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("m"),
          @lib.Name::from_string("effect"),
          @lib.ExternType::func(effect_type),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([i32_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::ref_i31(),
            @lib.Instruction::ref_null(eq_heap),
            @lib.Instruction::ref_eq(),
          ]),
        ),
      ]),
    ),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("ref.eq"), msg=pretty)
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("I32(0)"), msg=pretty)
}

///|
test "optimize-instructions folds impossible ref.test and ref.cast on local i31 refs" {
  let i32_type = @lib.TypeIdx::new(0U)
  let struct_result_type = @lib.TypeIdx::new(1U)
  let struct_heap = @lib.HeapType::abs(@lib.AbsHeapType::struct_())
  let struct_ref = @lib.ValType::ref_type(@lib.RefType::new(false, struct_heap))
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [struct_ref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([i32_type, struct_result_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::ref_i31(),
            @lib.Instruction::ref_test(false, struct_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::ref_i31(),
            @lib.Instruction::ref_cast(false, struct_heap),
          ]),
        ),
      ]),
    ),
  )
  let test_struct = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let cast_struct = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(test_struct.contains("ref.test"), msg=test_struct)
  assert_true(test_struct.contains("I32(0)"), msg=test_struct)
  assert_true(cast_struct.contains("unreachable"), msg=cast_struct)
  assert_false(cast_struct.contains("ref.cast"), msg=cast_struct)
}

///|
test "optimize-instructions folds successful ref.test and ref.cast on local ref.func refs" {
  let func_heap = @lib.HeapType::abs(@lib.AbsHeapType::func())
  let i32_type = @lib.TypeIdx::new(0U)
  let empty_type = @lib.TypeIdx::new(1U)
  let func_ref_type = @lib.TypeIdx::new(2U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::funcref()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([empty_type, i32_type, func_ref_type]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::ref_test(false, func_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::ref_cast(false, func_heap),
          ]),
        ),
      ]),
    ),
  )
  let test_func = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let cast_func = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(test_func.contains("ref.test"), msg=test_func)
  assert_true(test_func.contains("I32(1)"), msg=test_func)
  assert_true(cast_func.contains("ref.func"), msg=cast_func)
  assert_false(cast_func.contains("ref.cast"), msg=cast_func)
}

///|
test "optimize-instructions folds declared non-null i31 local ref.test and ref.cast to supertypes" {
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let i31_ref = @lib.ValType::ref_type(@lib.RefType::new(false, i31_heap))
  let eq_ref = @lib.ValType::ref_type(@lib.RefType::new(false, eq_heap))
  let any_ref = @lib.ValType::ref_type(@lib.RefType::new(false, any_heap))
  let i32_type = @lib.TypeIdx::new(0U)
  let eq_type = @lib.TypeIdx::new(1U)
  let any_type = @lib.TypeIdx::new(2U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([i31_ref], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([i31_ref], [eq_ref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([i31_ref], [any_ref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([i32_type, eq_type, i32_type, any_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(false, eq_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(false, eq_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(false, any_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(false, any_heap),
          ]),
        ),
      ]),
    ),
  )
  let test_eq = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let cast_eq = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let test_any = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let cast_any = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_false(test_eq.contains("ref.test"), msg=test_eq)
  assert_true(test_eq.contains("I32(1)"), msg=test_eq)
  assert_true(cast_eq.contains("local.get"), msg=cast_eq)
  assert_false(cast_eq.contains("ref.cast"), msg=cast_eq)
  assert_false(test_any.contains("ref.test"), msg=test_any)
  assert_true(test_any.contains("I32(1)"), msg=test_any)
  assert_true(cast_any.contains("local.get"), msg=cast_any)
  assert_false(cast_any.contains("ref.cast"), msg=cast_any)
}

///|
test "optimize-instructions folds successful ref.test and ref.cast on non-null struct array supertypes" {
  let struct_heap = @lib.HeapType::abs(@lib.AbsHeapType::struct_())
  let array_heap = @lib.HeapType::abs(@lib.AbsHeapType::array())
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let any_heap = @lib.HeapType::abs(@lib.AbsHeapType::any())
  let struct_ref = @lib.ValType::ref_type(@lib.RefType::new(false, struct_heap))
  let array_ref = @lib.ValType::ref_type(@lib.RefType::new(false, array_heap))
  let eq_ref = @lib.ValType::ref_type(@lib.RefType::new(false, eq_heap))
  let any_ref = @lib.ValType::ref_type(@lib.RefType::new(false, any_heap))
  let struct_i32_type = @lib.TypeIdx::new(0U)
  let eq_type = @lib.TypeIdx::new(1U)
  let array_i32_type = @lib.TypeIdx::new(2U)
  let any_type = @lib.TypeIdx::new(3U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([struct_ref], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([struct_ref], [eq_ref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([array_ref], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([array_ref], [any_ref])),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([struct_i32_type, eq_type, array_i32_type, any_type]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(false, eq_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(false, eq_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(false, any_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(false, any_heap),
          ]),
        ),
      ]),
    ),
  )
  let test_eq = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let cast_eq = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let test_any = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let cast_any = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_false(test_eq.contains("ref.test"), msg=test_eq)
  assert_true(test_eq.contains("I32(1)"), msg=test_eq)
  assert_true(cast_eq.contains("local.get"), msg=cast_eq)
  assert_false(cast_eq.contains("ref.cast"), msg=cast_eq)
  assert_false(test_any.contains("ref.test"), msg=test_any)
  assert_true(test_any.contains("I32(1)"), msg=test_any)
  assert_true(cast_any.contains("local.get"), msg=cast_any)
  assert_false(cast_any.contains("ref.cast"), msg=cast_any)
}

///|
test "optimize-instructions folds impossible ref.test and ref.cast between non-null struct array locals" {
  let struct_heap = @lib.HeapType::abs(@lib.AbsHeapType::struct_())
  let array_heap = @lib.HeapType::abs(@lib.AbsHeapType::array())
  let struct_ref = @lib.ValType::ref_type(@lib.RefType::new(false, struct_heap))
  let array_ref = @lib.ValType::ref_type(@lib.RefType::new(false, array_heap))
  let struct_i32_type = @lib.TypeIdx::new(0U)
  let struct_array_type = @lib.TypeIdx::new(1U)
  let array_i32_type = @lib.TypeIdx::new(2U)
  let array_struct_type = @lib.TypeIdx::new(3U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([struct_ref], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([struct_ref], [array_ref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([array_ref], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([array_ref], [struct_ref]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([
        struct_i32_type, struct_array_type, array_i32_type, array_struct_type,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(false, array_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(false, array_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(false, struct_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(false, struct_heap),
          ]),
        ),
      ]),
    ),
  )
  let test_array = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let cast_array = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let test_struct = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let cast_struct = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_false(test_array.contains("ref.test"), msg=test_array)
  assert_true(test_array.contains("I32(0)"), msg=test_array)
  assert_true(cast_array.contains("unreachable"), msg=cast_array)
  assert_false(cast_array.contains("ref.cast"), msg=cast_array)
  assert_false(test_struct.contains("ref.test"), msg=test_struct)
  assert_true(test_struct.contains("I32(0)"), msg=test_struct)
  assert_true(cast_struct.contains("unreachable"), msg=cast_struct)
  assert_false(cast_struct.contains("ref.cast"), msg=cast_struct)
}

///|
test "optimize-instructions covers impossible nullable-target ref.test and ref.cast on non-null disjoint locals" {
  let struct_heap = @lib.HeapType::abs(@lib.AbsHeapType::struct_())
  let array_heap = @lib.HeapType::abs(@lib.AbsHeapType::array())
  let struct_ref = @lib.ValType::ref_type(@lib.RefType::new(false, struct_heap))
  let nullable_array_ref = @lib.ValType::ref_null(array_heap)
  let struct_i32_type = @lib.TypeIdx::new(0U)
  let struct_array_type = @lib.TypeIdx::new(1U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([struct_ref], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([struct_ref], [nullable_array_ref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([struct_i32_type, struct_array_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(true, array_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(true, array_heap),
          ]),
        ),
      ]),
    ),
  )
  let test_array = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let cast_array = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(test_array.contains("ref.test"), msg=test_array)
  assert_true(test_array.contains("I32(0)"), msg=test_array)
  assert_true(cast_array.contains("unreachable"), msg=cast_array)
  assert_false(cast_array.contains("ref.cast"), msg=cast_array)
}

///|
test "optimize-instructions folds non-null target ref.test and ref.cast on nullable disjoint locals" {
  let struct_heap = @lib.HeapType::abs(@lib.AbsHeapType::struct_())
  let array_heap = @lib.HeapType::abs(@lib.AbsHeapType::array())
  let nullable_struct_ref = @lib.ValType::ref_null(struct_heap)
  let array_ref = @lib.ValType::ref_type(@lib.RefType::new(false, array_heap))
  let struct_i32_type = @lib.TypeIdx::new(0U)
  let struct_array_type = @lib.TypeIdx::new(1U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_struct_ref], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_struct_ref], [array_ref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([struct_i32_type, struct_array_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(false, array_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(false, array_heap),
          ]),
        ),
      ]),
    ),
  )
  let test_array = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let cast_array = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(test_array.contains("ref.test"), msg=test_array)
  assert_true(test_array.contains("I32(0)"), msg=test_array)
  assert_true(cast_array.contains("unreachable"), msg=cast_array)
  assert_false(cast_array.contains("ref.cast"), msg=cast_array)
}

///|
test "optimize-instructions covers successful nullable-target ref.test and ref.cast on non-null local supertypes" {
  let struct_heap = @lib.HeapType::abs(@lib.AbsHeapType::struct_())
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let struct_ref = @lib.ValType::ref_type(@lib.RefType::new(false, struct_heap))
  let nullable_eq_ref = @lib.ValType::ref_null(eq_heap)
  let struct_i32_type = @lib.TypeIdx::new(0U)
  let struct_eq_type = @lib.TypeIdx::new(1U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([struct_ref], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([struct_ref], [nullable_eq_ref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([struct_i32_type, struct_eq_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(true, eq_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(true, eq_heap),
          ]),
        ),
      ]),
    ),
  )
  let test_eq = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let cast_eq = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(test_eq.contains("ref.test"), msg=test_eq)
  assert_true(test_eq.contains("I32(1)"), msg=test_eq)
  assert_true(cast_eq.contains("local.get"), msg=cast_eq)
  assert_false(cast_eq.contains("ref.cast"), msg=cast_eq)
}

///|
test "optimize-instructions folds nullable-source nullable-target ref.test and ref.cast on local supertypes" {
  let struct_heap = @lib.HeapType::abs(@lib.AbsHeapType::struct_())
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let nullable_struct_ref = @lib.ValType::ref_null(struct_heap)
  let nullable_eq_ref = @lib.ValType::ref_null(eq_heap)
  let struct_i32_type = @lib.TypeIdx::new(0U)
  let struct_eq_type = @lib.TypeIdx::new(1U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_struct_ref], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_struct_ref], [nullable_eq_ref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([struct_i32_type, struct_eq_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(true, eq_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(true, eq_heap),
          ]),
        ),
      ]),
    ),
  )
  let test_eq = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let cast_eq = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(test_eq.contains("ref.test"), msg=test_eq)
  assert_true(test_eq.contains("I32(1)"), msg=test_eq)
  assert_true(cast_eq.contains("local.get"), msg=cast_eq)
  assert_false(cast_eq.contains("ref.cast"), msg=cast_eq)
}

///|
test "optimize-instructions covers nullable-source nullable-target i31 ref.test and ref.cast on local supertypes" {
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let nullable_i31_ref = @lib.ValType::ref_null(i31_heap)
  let nullable_eq_ref = @lib.ValType::ref_null(eq_heap)
  let i31_i32_type = @lib.TypeIdx::new(0U)
  let i31_eq_type = @lib.TypeIdx::new(1U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_i31_ref], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_i31_ref], [nullable_eq_ref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([i31_i32_type, i31_eq_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(true, eq_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(true, eq_heap),
          ]),
        ),
      ]),
    ),
  )
  let test_eq = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let cast_eq = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(test_eq.contains("ref.test"), msg=test_eq)
  assert_true(test_eq.contains("I32(1)"), msg=test_eq)
  assert_true(cast_eq.contains("local.get"), msg=cast_eq)
  assert_false(cast_eq.contains("ref.cast"), msg=cast_eq)
}

///|
test "optimize-instructions folds successful ref.test and ref.cast on non-null local refs" {
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let eq_ref = @lib.ValType::ref_type(@lib.RefType::new(false, eq_heap))
  let i32_type = @lib.TypeIdx::new(0U)
  let eq_type = @lib.TypeIdx::new(1U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([eq_ref], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([eq_ref], [eq_ref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([i32_type, eq_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(false, eq_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(false, eq_heap),
          ]),
        ),
      ]),
    ),
  )
  let test_eq = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let cast_eq = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(test_eq.contains("ref.test"), msg=test_eq)
  assert_true(test_eq.contains("I32(1)"), msg=test_eq)
  assert_true(cast_eq.contains("local.get"), msg=cast_eq)
  assert_false(cast_eq.contains("ref.cast"), msg=cast_eq)
}

///|
test "optimize-instructions collapses casts fed by unreachable ref.as_non_null" {
  let func_heap = @lib.HeapType::abs(@lib.AbsHeapType::func())
  let func_ref = @lib.ValType::ref_type(@lib.RefType::new(false, func_heap))
  let func_type = @lib.TypeIdx::new(0U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [func_ref])),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::ref_null(func_heap),
            @lib.Instruction::ref_as_non_null(),
            @lib.Instruction::ref_cast(false, func_heap),
          ]),
        ),
      ]),
    ),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("ref.as_non_null"), msg=pretty)
  assert_false(pretty.contains("ref.cast"), msg=pretty)
}

///|
test "optimize-instructions rewrites ref.eq null comparisons through ref.is_null" {
  let source =
    #|(module
    #|  (func (export "right") (param eqref) (result i32)
    #|    local.get 0
    #|    ref.null eq
    #|    ref.eq)
    #|  (func (export "left") (param eqref) (result i32)
    #|    ref.null eq
    #|    local.get 0
    #|    ref.eq)
    #|  (func (export "null-null") (result i32)
    #|    ref.null eq
    #|    ref.null eq
    #|    ref.eq)
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ref.eq optimize success, got \{err}")
  }
  let right_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let left_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let null_null_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(right_pretty.contains("ref.eq"), msg=right_pretty)
  // pretty_print currently spells the lowered RefIsNull instruction as
  // `ref.null`; lock the OI rewrite by proving `ref.eq` is gone while the
  // operand-preserving unary reference check remains.
  assert_true(right_pretty.contains("local.get"), msg=right_pretty)
  assert_true(right_pretty.contains("ref.null"), msg=right_pretty)
  assert_false(left_pretty.contains("ref.eq"), msg=left_pretty)
  assert_true(left_pretty.contains("local.get"), msg=left_pretty)
  assert_true(left_pretty.contains("ref.null"), msg=left_pretty)
  assert_false(null_null_pretty.contains("ref.eq"), msg=null_null_pretty)
  assert_false(null_null_pretty.contains("ref.is_null"), msg=null_null_pretty)
  assert_true(null_null_pretty.contains("I32(1)"), msg=null_null_pretty)
}

///|
test "optimize-instructions directizes ref.func call_ref targets" {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let callee_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([callee_type]))
    .with_func_sec(
      @lib.FuncSec::new([callee_type_idx, callee_type_idx, callee_type_idx]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::call_ref(callee_type_idx),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::return_call_ref(callee_type_idx),
          ]),
        ),
      ]),
    ),
  )
  let caller = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let tail = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(caller.contains("call (Func 0)"), msg=caller)
  assert_false(caller.contains("call_ref"), msg=caller)
  assert_false(caller.contains("ref.func"), msg=caller)
  assert_true(tail.contains("return_call (Func 0)"), msg=tail)
  assert_false(tail.contains("return_call_ref"), msg=tail)
  assert_false(tail.contains("ref.func"), msg=tail)
}

///|
test "optimize-instructions lowers select ref.func call_ref targets to direct if calls" {
  let target_type_idx = @lib.TypeIdx::new(0U)
  let caller_type_idx = @lib.TypeIdx::new(1U)
  let target_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let caller_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let typed_func_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(target_type_idx)),
  )
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([target_type, caller_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        target_type_idx, target_type_idx, caller_type_idx, caller_type_idx,
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U), @lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(10))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(20))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::select(types=Some([typed_func_ref])),
            @lib.Instruction::call_ref(target_type_idx),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::select(types=Some([typed_func_ref])),
            @lib.Instruction::return_call_ref(target_type_idx),
          ]),
        ),
      ]),
    ),
  )
  let caller = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let tail = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(caller.contains("if"), msg=caller)
  assert_true(caller.contains("call (Func 0)"), msg=caller)
  assert_true(caller.contains("call (Func 1)"), msg=caller)
  assert_false(caller.contains("call_ref"), msg=caller)
  assert_false(caller.contains("select"), msg=caller)
  assert_false(caller.contains("ref.func"), msg=caller)
  assert_true(tail.contains("if"), msg=tail)
  assert_true(tail.contains("return_call (Func 0)"), msg=tail)
  assert_true(tail.contains("return_call (Func 1)"), msg=tail)
  assert_false(tail.contains("return_call_ref"), msg=tail)
  assert_false(tail.contains("select"), msg=tail)
  assert_false(tail.contains("ref.func"), msg=tail)
}

///|
test "optimize-instructions localizes argument select call_ref targets before direct calls" {
  let target_type_idx = @lib.TypeIdx::new(0U)
  let caller_type_idx = @lib.TypeIdx::new(1U)
  let target_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let caller_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
        @lib.ValType::i32(),
      ]),
    ),
  )
  let typed_func_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(target_type_idx)),
  )
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([target_type, caller_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        target_type_idx, target_type_idx, caller_type_idx, caller_type_idx,
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U), @lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_add(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::select(types=Some([typed_func_ref])),
            @lib.Instruction::call_ref(target_type_idx),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::select(types=Some([typed_func_ref])),
            @lib.Instruction::return_call_ref(target_type_idx),
          ]),
        ),
      ]),
    ),
  )
  let caller = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let tail = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(caller.contains("local.set"), msg=caller)
  assert_true(caller.contains("local.get"), msg=caller)
  assert_true(caller.contains("if"), msg=caller)
  assert_true(caller.contains("call (Func 0)"), msg=caller)
  assert_true(caller.contains("call (Func 1)"), msg=caller)
  assert_false(caller.contains("call_ref"), msg=caller)
  assert_false(caller.contains("select"), msg=caller)
  assert_false(caller.contains("ref.func"), msg=caller)
  assert_true(tail.contains("local.set"), msg=tail)
  assert_true(tail.contains("local.get"), msg=tail)
  assert_true(tail.contains("if"), msg=tail)
  assert_true(tail.contains("return_call (Func 0)"), msg=tail)
  assert_true(tail.contains("return_call (Func 1)"), msg=tail)
  assert_false(tail.contains("return_call_ref"), msg=tail)
  assert_false(tail.contains("select"), msg=tail)
  assert_false(tail.contains("ref.func"), msg=tail)
}

///|
test "optimize-instructions intentionally keeps select call_ref when an arm is not direct ref.func" {
  let target_type_idx = @lib.TypeIdx::new(0U)
  let caller_type_idx = @lib.TypeIdx::new(1U)
  let target_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let caller_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
        @lib.ValType::i32(),
      ]),
    ),
  )
  let nullable_func_ref = @lib.RefType::new(
    true,
    @lib.HeapType::new(target_type_idx),
  )
  let typed_func_ref = @lib.ValType::ref_type(nullable_func_ref)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([target_type, caller_type]))
    .with_func_sec(
      @lib.FuncSec::new([target_type_idx, target_type_idx, caller_type_idx]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(nullable_func_ref, @lib.Limits::i32(1U, Some(1U))),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::active(
            @lib.TableIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
          ),
          @lib.ElemKind::typed_exprs(nullable_func_ref, [
            @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(1U))]),
          ]),
        ),
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U), @lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_add(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::table_get(@lib.TableIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::select(types=Some([typed_func_ref])),
            @lib.Instruction::call_ref(target_type_idx),
          ]),
        ),
      ]),
    ),
  )
  let caller = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(caller.contains("call_ref"), msg=caller)
  assert_true(caller.contains("select"), msg=caller)
  assert_true(caller.contains("table.get"), msg=caller)
  assert_true(caller.contains("ref.func"), msg=caller)
}

///|
test "optimize-instructions intentionally keeps argument fallthrough call_ref targets" {
  let target_type_idx = @lib.TypeIdx::new(0U)
  let arg_effect_type_idx = @lib.TypeIdx::new(1U)
  let target_effect_type_idx = @lib.TypeIdx::new(2U)
  let caller_type_idx = @lib.TypeIdx::new(3U)
  let target_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let arg_effect_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let target_effect_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let caller_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let typed_func_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(target_type_idx)),
  )
  let effectful_target = fn() {
    @lib.Instruction::block(
      @lib.BlockType::val_type(typed_func_ref),
      @lib.Expr::new([
        @lib.Instruction::call(@lib.FuncIdx::new(2U)),
        @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
      ]),
    )
  }
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        target_type, arg_effect_type, target_effect_type, caller_type,
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([
        target_type_idx, arg_effect_type_idx, target_effect_type_idx, caller_type_idx,
        caller_type_idx,
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(7))]),
        ),
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            effectful_target(),
            @lib.Instruction::call_ref(target_type_idx),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
            effectful_target(),
            @lib.Instruction::return_call_ref(target_type_idx),
          ]),
        ),
      ]),
    ),
  )
  let caller = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  let tail = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  assert_true(caller.contains("call_ref"), msg=caller)
  assert_true(caller.contains("call (Func 1)"), msg=caller)
  assert_true(caller.contains("call (Func 2)"), msg=caller)
  assert_true(caller.contains("ref.func"), msg=caller)
  assert_true(tail.contains("return_call_ref"), msg=tail)
  assert_true(tail.contains("call (Func 1)"), msg=tail)
  assert_true(tail.contains("call (Func 2)"), msg=tail)
  assert_true(tail.contains("ref.func"), msg=tail)
}

///|
test "optimize-instructions directizes fallthrough ref.func call_ref targets and preserves target effects" {
  let target_type_idx = @lib.TypeIdx::new(0U)
  let side_type_idx = @lib.TypeIdx::new(1U)
  let caller_type_idx = @lib.TypeIdx::new(2U)
  let target_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let side_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let caller_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let typed_func_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(target_type_idx)),
  )
  let effectful_target = fn() {
    @lib.Instruction::block(
      @lib.BlockType::val_type(typed_func_ref),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::call(@lib.FuncIdx::new(1U)),
        @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
      ]),
    )
  }
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([target_type, side_type, caller_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        target_type_idx, side_type_idx, caller_type_idx, caller_type_idx,
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(42))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::drop(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            effectful_target(),
            @lib.Instruction::call_ref(target_type_idx),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            effectful_target(),
            @lib.Instruction::return_call_ref(target_type_idx),
          ]),
        ),
      ]),
    ),
  )
  let caller = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let tail = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(caller.contains("call (Func 1)"), msg=caller)
  assert_true(caller.contains("call (Func 0)"), msg=caller)
  assert_false(caller.contains("call_ref"), msg=caller)
  assert_true(caller.contains("ref.func"), msg=caller)
  assert_true(tail.contains("call (Func 1)"), msg=tail)
  assert_true(tail.contains("return_call (Func 0)"), msg=tail)
  assert_false(tail.contains("return_call_ref"), msg=tail)
  assert_true(tail.contains("ref.func"), msg=tail)
}

///|
test "optimize-instructions lowers table.get call_ref targets to indirect calls" {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let callee_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let typed_func_ref = @lib.RefType::new(
    true,
    @lib.HeapType::new(callee_type_idx),
  )
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([callee_type]))
    .with_func_sec(
      @lib.FuncSec::new([callee_type_idx, callee_type_idx, callee_type_idx]),
    )
    .with_table_sec(
      @lib.TableSec::new([
        @lib.Table::new(
          @lib.TableType::new(typed_func_ref, @lib.Limits::i32(1U, Some(1U))),
          None,
        ),
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::active(
            @lib.TableIdx::new(0U),
            @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(0))]),
          ),
          @lib.ElemKind::typed_exprs(typed_func_ref, [
            @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(0U))]),
          ]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::table_get(@lib.TableIdx::new(0U)),
            @lib.Instruction::call_ref(callee_type_idx),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::table_get(@lib.TableIdx::new(0U)),
            @lib.Instruction::return_call_ref(callee_type_idx),
          ]),
        ),
      ]),
    ),
  )
  let caller = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let tail = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(caller.contains("call_indirect (Type 0) (Table 0)"), msg=caller)
  assert_false(caller.contains("call_ref"), msg=caller)
  assert_false(caller.contains("table.get"), msg=caller)
  assert_true(
    tail.contains("return_call_indirect (Type 0) (Table 0)"),
    msg=tail,
  )
  assert_false(tail.contains("return_call_ref"), msg=tail)
  assert_false(tail.contains("table.get"), msg=tail)
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
test "optimize-instructions expands wider tiny memory.copy to exact load/store" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $dst i32) (param $src i32)
        #|    local.get $dst
        #|    local.get $src
        #|    i32.const 2
        #|    memory.copy
        #|    local.get $dst
        #|    local.get $src
        #|    i32.const 4
        #|    memory.copy
        #|    local.get $dst
        #|    local.get $src
        #|    i32.const 8
        #|    memory.copy))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected wider memory.copy optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("memory.copy"), msg=pretty)
  optimize_instructions_assert_strings_in_order(pretty, [
    "i32.load16u", "i32.store16", "i32.load", "i32.store", "i64.load", "i64.store",
  ])
}

///|
test "optimize-instructions expands memory64 tiny memory.copy preserving i64 addresses" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i64(), @lib.ValType::i64()], []),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i64(1UL, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(1L)),
            @lib.Instruction::memory_copy(
              @lib.MemIdx::new(0U),
              @lib.MemIdx::new(0U),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(8L)),
            @lib.Instruction::memory_copy(
              @lib.MemIdx::new(0U),
              @lib.MemIdx::new(0U),
            ),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(err) => fail("expected valid memory64 input, got \{err}")
  }
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected memory64 memory.copy optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("memory.copy"), msg=pretty)
  optimize_instructions_assert_strings_in_order(pretty, [
    "(local.get (Local 0))", "(local.get (Local 1))", "i32.load8u", "i32.store8",
    "(local.get (Local 0))", "(local.get (Local 1))", "i64.load", "i64.store",
  ])
}

///|
test "optimize-instructions expands memory64 tiny memory.fill preserving i64 address and length" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i64(), @lib.ValType::i32()], []),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i64(1UL, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(1L)),
            @lib.Instruction::memory_fill(@lib.MemIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(8L)),
            @lib.Instruction::memory_fill(@lib.MemIdx::new(0U)),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(err) => fail("expected valid memory64 memory.fill input, got \{err}")
  }
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected memory64 memory.fill optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("memory.fill"), msg=pretty)
  optimize_instructions_assert_strings_in_order(pretty, [
    "(local.get (Local 0))", "i32.store8", "(local.get (Local 0))", "i64.store",
  ])
}

///|
test "optimize-instructions keeps memory64 memory.copy outside exact tiny lowering boundary" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func(
        [@lib.ValType::i64(), @lib.ValType::i64(), @lib.ValType::i64()],
        [],
      ),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i64(1UL, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i64_const(@lib.I64(2147483648L)),
            @lib.Instruction::memory_copy(
              @lib.MemIdx::new(0U),
              @lib.MemIdx::new(0U),
            ),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::memory_copy(
              @lib.MemIdx::new(0U),
              @lib.MemIdx::new(0U),
            ),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(err) => fail("expected valid memory64 boundary input, got \{err}")
  }
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected memory64 memory.copy boundary success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  // Intentional fail-closed memory64 boundary: exact tiny lowering only accepts
  // constant sizes representable as local Int values and never proves dynamic
  // memory64 lengths, so oversized and nonconstant lengths remain bulk copies.
  @debug.assert_eq(
    optimize_instructions_test_count_substring(pretty, "memory.copy"),
    2,
    msg=pretty,
  )
  assert_false(pretty.contains("i32.load8u"), msg=pretty)
  assert_false(pretty.contains("i64.load"), msg=pretty)
}

///|
test "optimize-instructions keeps memory.copy outside exact tiny lowering boundary" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $dst i32) (param $src i32) (param $size i32)
        #|    local.get $dst
        #|    local.get $src
        #|    i32.const 0
        #|    memory.copy
        #|    local.get $dst
        #|    local.get $src
        #|    i32.const 16
        #|    memory.copy
        #|    local.get $dst
        #|    local.get $src
        #|    local.get $size
        #|    memory.copy))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected memory.copy boundary optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  // Intentional fail-closed boundary: without trap-relaxed mode support, a
  // zero-size memory.copy is kept; without multi-store overlap proof and a
  // side-effect-free constant size, larger/nonconstant copies are kept too.
  @debug.assert_eq(
    optimize_instructions_test_count_substring(pretty, "memory.copy"),
    3,
    msg=pretty,
  )
  assert_false(pretty.contains("i32.load8u"), msg=pretty)
  assert_false(pretty.contains("i32.store8"), msg=pretty)
  assert_false(pretty.contains("i32.load16u"), msg=pretty)
  assert_false(pretty.contains("i32.store16"), msg=pretty)
  assert_false(pretty.contains("i64.load"), msg=pretty)
  assert_false(pretty.contains("i64.store"), msg=pretty)
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
test "optimize-instructions truncates constant byte memory.fill values before store8" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $dst i32)
        #|    local.get $dst
        #|    i32.const -1
        #|    i32.const 1
        #|    memory.fill
        #|    local.get $dst
        #|    i32.const 511
        #|    i32.const 1
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected byte memory.fill truncation success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("memory.fill"), msg=pretty)
  assert_false(pretty.contains("I32(-1)"), msg=pretty)
  assert_false(pretty.contains("I32(511)"), msg=pretty)
  optimize_instructions_assert_strings_in_order(pretty, [
    "I32(255)", "i32.store8", "I32(255)", "i32.store8",
  ])
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
test "optimize-instructions expands local eight-byte memory.fill to store" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $dst i32) (param $value i32)
        #|    local.get $dst
        #|    local.get $value
        #|    i32.const 8
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected local eight-byte memory.fill optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("memory.fill"), msg=pretty)
  assert_true(pretty.contains("i64.store"), msg=pretty)
  assert_true(pretty.contains("i32.and"), msg=pretty)
  assert_true(pretty.contains("I32(255)"), msg=pretty)
  assert_true(pretty.contains("i64.extend_i32u"), msg=pretty)
  assert_true(pretty.contains("i64.mul"), msg=pretty)
  assert_true(pretty.contains("I64(72340172838076673)"), msg=pretty)
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
test "optimize-instructions drops masked low bits before narrow stores" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $ptr i32) (param $value i32)
        #|    local.get $ptr
        #|    local.get $value
        #|    i32.const 255
        #|    i32.and
        #|    i32.store8
        #|    local.get $ptr
        #|    local.get $value
        #|    i32.const 65535
        #|    i32.and
        #|    i32.store16))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected narrow store optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("i32.and"), msg=pretty)
  optimize_instructions_assert_strings_in_order(pretty, [
    "(local.get (Local 0))", "(local.get (Local 1))", "i32.store8", "(local.get (Local 0))",
    "(local.get (Local 1))", "i32.store16",
  ])
}

///|
test "optimize-instructions keeps value-changing masks before narrow stores" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $ptr i32) (param $value i32)
        #|    local.get $ptr
        #|    local.get $value
        #|    i32.const 127
        #|    i32.and
        #|    i32.store8
        #|    local.get $ptr
        #|    local.get $value
        #|    i32.const 32767
        #|    i32.and
        #|    i32.store16))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected narrow store boundary success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.and"), msg=pretty)
  assert_true(pretty.contains("i32.store8"), msg=pretty)
  assert_true(pretty.contains("i32.store16"), msg=pretty)
}

///|
test "optimize-instructions drops masked low bits before i64 narrow stores" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $ptr i32) (param $value i64)
        #|    local.get $ptr
        #|    local.get $value
        #|    i64.const 255
        #|    i64.and
        #|    i64.store8
        #|    local.get $ptr
        #|    local.get $value
        #|    i64.const 65535
        #|    i64.and
        #|    i64.store16
        #|    local.get $ptr
        #|    local.get $value
        #|    i64.const 4294967295
        #|    i64.and
        #|    i64.store32))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected i64 narrow store optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("i64.and"), msg=pretty)
  optimize_instructions_assert_strings_in_order(pretty, [
    "(local.get (Local 0))", "(local.get (Local 1))", "i64.store8", "(local.get (Local 0))",
    "(local.get (Local 1))", "i64.store16", "(local.get (Local 0))", "(local.get (Local 1))",
    "i64.store32",
  ])
}

///|
test "optimize-instructions drops commuted masks before narrow stores" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $ptr i32) (param $value32 i32) (param $value64 i64)
        #|    local.get $ptr
        #|    i32.const 255
        #|    local.get $value32
        #|    i32.and
        #|    i32.store8
        #|    local.get $ptr
        #|    i32.const 65535
        #|    local.get $value32
        #|    i32.and
        #|    i32.store16
        #|    local.get $ptr
        #|    i64.const 255
        #|    local.get $value64
        #|    i64.and
        #|    i64.store8
        #|    local.get $ptr
        #|    i64.const 65535
        #|    local.get $value64
        #|    i64.and
        #|    i64.store16
        #|    local.get $ptr
        #|    i64.const 4294967295
        #|    local.get $value64
        #|    i64.and
        #|    i64.store32))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected commuted narrow store optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("i32.and"), msg=pretty)
  assert_false(pretty.contains("i64.and"), msg=pretty)
  optimize_instructions_assert_strings_in_order(pretty, [
    "(local.get (Local 0))", "(local.get (Local 1))", "i32.store8", "(local.get (Local 0))",
    "(local.get (Local 1))", "i32.store16", "(local.get (Local 0))", "(local.get (Local 2))",
    "i64.store8", "(local.get (Local 0))", "(local.get (Local 2))", "i64.store16",
    "(local.get (Local 0))", "(local.get (Local 2))", "i64.store32",
  ])
}

///|
test "optimize-instructions truncates constant narrow store values" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $ptr i32)
        #|    local.get $ptr
        #|    i32.const -1
        #|    i32.store8
        #|    local.get $ptr
        #|    i32.const 65537
        #|    i32.store16
        #|    local.get $ptr
        #|    i64.const 511
        #|    i64.store8
        #|    local.get $ptr
        #|    i64.const 65537
        #|    i64.store16
        #|    local.get $ptr
        #|    i64.const 4294967296
        #|    i64.store32))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected constant narrow store optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("I32(-1)"), msg=pretty)
  assert_false(pretty.contains("I32(65537)"), msg=pretty)
  assert_false(pretty.contains("I64(511)"), msg=pretty)
  assert_false(pretty.contains("I64(65537)"), msg=pretty)
  assert_false(pretty.contains("I64(4294967296)"), msg=pretty)
  optimize_instructions_assert_strings_in_order(pretty, [
    "I32(255)", "i32.store8", "I32(1)", "i32.store16", "I64(255)", "i64.store8",
    "I64(1)", "i64.store16", "I64(0)", "i64.store32",
  ])
}

///|
test "optimize-instructions keeps value-changing masks before i64 narrow stores" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $ptr i32) (param $value i64)
        #|    local.get $ptr
        #|    local.get $value
        #|    i64.const 127
        #|    i64.and
        #|    i64.store8
        #|    local.get $ptr
        #|    local.get $value
        #|    i64.const 32767
        #|    i64.and
        #|    i64.store16
        #|    local.get $ptr
        #|    local.get $value
        #|    i64.const 2147483647
        #|    i64.and
        #|    i64.store32))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected i64 narrow store boundary success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i64.and"), msg=pretty)
  assert_true(pretty.contains("i64.store8"), msg=pretty)
  assert_true(pretty.contains("i64.store16"), msg=pretty)
  assert_true(pretty.contains("i64.store32"), msg=pretty)
}

///|
test "optimize-instructions folds constant memory access offset into i32 address" {
  let load_func = optimize_instructions_test_run_hot(
    "(module (memory 1) (func (result i32) i32.const 8 i32.load offset=4))",
  )
  let load = @ir.hot_root_get(load_func, 0)
  let load_addr = @ir.hot_child_get(load_func, load, 0)
  @debug.assert_eq(
    @ir.hot_const_get(load_func, @ir.hot_node_get(load_func, load_addr).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(12)),
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(load_func, load),
    Some(
      @lib.Instruction::i32_load(
        @lib.MemArg::new(@lib.U32(2), None, @lib.U64(0)),
      ),
    ),
  )

  let store_func = optimize_instructions_test_run_hot(
    "(module (memory 1) (func i32.const 16 i32.const 99 i32.store offset=12))",
  )
  let store = @ir.hot_root_get(store_func, 0)
  let store_addr = @ir.hot_child_get(store_func, store, 0)
  @debug.assert_eq(
    @ir.hot_const_get(store_func, @ir.hot_node_get(store_func, store_addr).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(28)),
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(store_func, store),
    Some(
      @lib.Instruction::i32_store(
        @lib.MemArg::new(@lib.U32(2), None, @lib.U64(0)),
      ),
    ),
  )
}

///|
test "optimize-instructions folds constant memory64 access offset into i64 address" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i64(1UL, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i64_const(@lib.I64(8L)),
            @lib.Instruction::i32_load(
              @lib.MemArg::new(@lib.U32(2), None, @lib.U64(4)),
            ),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(err) =>
      fail("expected valid memory64 constant-offset input, got \{err}")
  }
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected memory64 constant-offset optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i64.const I64(12)"), msg=pretty)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_false(pretty.contains("offset=U64(4)"), msg=pretty)
}

///|
test "optimize-instructions intentionally keeps nonconstant pointer-add memory offsets outside OI ownership" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $p i32) (result i32)
        #|    local.get $p
        #|    i32.const 4
        #|    i32.add
        #|    i32.load offset=8)
        #|  (func (param $p i32) (param $v i32)
        #|    local.get $p
        #|    i32.const 4
        #|    i32.add
        #|    local.get $v
        #|    i32.store offset=8))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pointer-add offset boundary success, got \{err}")
  }
  let load_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let store_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  // Intentional fail-closed OI-G boundary: Binaryen `version_130`
  // `optimize-instructions` folds only constant address children with static
  // offsets. Pointer-add address arithmetic is left to other passes rather than
  // claimed as OI-owned load/store canonicalization.
  assert_true(load_pretty.contains("i32.add"), msg=load_pretty)
  assert_true(load_pretty.contains("offset=U64(8)"), msg=load_pretty)
  assert_false(load_pretty.contains("offset=U64(12)"), msg=load_pretty)
  assert_true(store_pretty.contains("i32.add"), msg=store_pretty)
  assert_true(store_pretty.contains("offset=U64(8)"), msg=store_pretty)
  assert_false(store_pretty.contains("offset=U64(12)"), msg=store_pretty)
}

///|
test "optimize-instructions folds constant memory64 store offset into i64 address" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i64(1UL, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i64_const(@lib.I64(16L)),
            @lib.Instruction::i32_const(@lib.I32(99)),
            @lib.Instruction::i32_store(
              @lib.MemArg::new(@lib.U32(2), None, @lib.U64(12)),
            ),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(err) => fail("expected valid memory64 store-offset input, got \{err}")
  }
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected memory64 store-offset optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i64.const I64(28)"), msg=pretty)
  assert_true(pretty.contains("i32.store"), msg=pretty)
  assert_false(pretty.contains("offset=U64(12)"), msg=pretty)
}

///|
test "optimize-instructions keeps memory64 access offsets that would wrap u64 address" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i64(1UL, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i64_const(@lib.I64(-8L)),
            @lib.Instruction::i32_load(
              @lib.MemArg::new(@lib.U32(2), None, @lib.U64(16)),
            ),
          ]),
        ),
      ]),
    )
  match @validate.validate_module(input) {
    Ok(_) => ()
    Err(err) =>
      fail("expected valid memory64 offset-overflow input, got \{err}")
  }
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected memory64 offset-overflow optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  // Intentional fail-closed memory64 boundary matching Binaryen's unsigned
  // effective-address guard: the fold is skipped when address + offset would
  // wrap the u64 memory64 address space.
  assert_true(pretty.contains("i64.const I64(-8)"), msg=pretty)
  assert_true(pretty.contains("offset=U64(16)"), msg=pretty)
}

///|
test "optimize-instructions keeps memory access offsets that would escape i32 positive range" {
  let func = optimize_instructions_test_run_hot(
    "(module (memory 1) (func (result i32) i32.const 2147483640 i32.load offset=16))",
  )
  let load = @ir.hot_root_get(func, 0)
  let load_addr = @ir.hot_child_get(func, load, 0)
  // Intentional fail-closed boundary matching Binaryen's memory32 guard: the
  // fold only fires when the constant address, offset, and sum all fit in the
  // nonnegative i32 range, so wrapping/overflow-adjacent forms keep the offset.
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, load_addr).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(2147483640)),
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, load),
    Some(
      @lib.Instruction::i32_load(
        @lib.MemArg::new(@lib.U32(2), None, @lib.U64(16)),
      ),
    ),
  )
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
