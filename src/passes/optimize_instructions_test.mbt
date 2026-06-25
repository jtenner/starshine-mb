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
test "optimize-instructions public pipeline canonicalizes simple stack-carried call operands" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (param i32) (result i32)
        #|    local.get 0
        #|    call $one
        #|    i32.add)
        #|  (func $one (result i32)
        #|    i32.const 1))
        #|,
      ),
      ["optimize-instructions"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected optimize-instructions call cleanup success, got \{err}")
  }
  assert_false(
    trace.any(fn(line) { line.contains("pass[optimize-instructions]:skip-raw") }),
    msg="unexpected raw skip in \{trace}",
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  optimize_instructions_assert_strings_in_order(pretty, [
    "call (Func 1)", "local.get (Local 0)", "i32.add",
  ])
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
test "optimize-instructions folds load-call constant memory offsets through narrow raw-gate escape" {
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
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[optimize-instructions]:skip-raw reason=load-call-optimize-instructions-noop",
      )
    }),
    msg="unexpected load-call raw skip",
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  // Binaryen version_130 folds the constant address and static offset even when
  // a call follows the dropped load. The escape remains exact: constant address,
  // nonzero static-offset load, drop, then direct call.
  assert_true(pretty.contains("i32.const I32(12)"), msg=pretty)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_false(pretty.contains("offset=U64(4)"), msg=pretty)
  assert_false(pretty.contains("i32.const I32(8)"), msg=pretty)
}

///|
test "optimize-instructions intentionally keeps nonconstant load-call offset boundary" {
  // Boundary-only OI-G classification: Binaryen `version_130`
  // `--optimize-instructions` keeps the probed nonconstant pointer load plus
  // following call spelling (`.tmp/oi-g-load-call-nonconst-offset-boundary-probe.wat`).
  // Starshine's raw-gate escape remains intentionally limited to the exact
  // constant-address load/drop/call shape, so this fixture prevents that narrow
  // implementation from being reported as broader mixed load/call parity.
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (import "m" "touch" (func $touch))
        #|  (memory 1)
        #|  (func (param $ptr i32)
        #|    local.get $ptr
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
      fail("expected nonconstant load-call offset boundary success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[optimize-instructions]:skip-raw reason=load-call-optimize-instructions-noop",
      )
    }),
    msg="expected load-call raw skip in \{trace}",
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(
    pretty.contains("i32.load align=U32(2) offset=U64(4)"),
    msg=pretty,
  )
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_false(pretty.contains("i32.const I32(4)"), msg=pretty)
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
test "optimize-instructions folds same-local integer compares" {
  let eq_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 local.get 0 i32.eq))",
  )
  let eq_root = @ir.hot_root_get(eq_func, 0)
  match @ir.hot_node_get(eq_func, eq_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected same-local i32.eq to fold to a const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(eq_func, @ir.hot_node_get(eq_func, eq_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )

  let ne_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 local.get 0 i32.ne))",
  )
  let ne_root = @ir.hot_root_get(ne_func, 0)
  match @ir.hot_node_get(ne_func, ne_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected same-local i32.ne to fold to a const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(ne_func, @ir.hot_node_get(ne_func, ne_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )

  let lt_func = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i32) local.get 0 local.get 0 i64.lt_s))",
  )
  let lt_root = @ir.hot_root_get(lt_func, 0)
  match @ir.hot_node_get(lt_func, lt_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected same-local i64.lt_s to fold to a const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(lt_func, @ir.hot_node_get(lt_func, lt_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )

  let ge_func = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i32) local.get 0 local.get 0 i64.ge_u))",
  )
  let ge_root = @ir.hot_root_get(ge_func, 0)
  match @ir.hot_node_get(ge_func, ge_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected same-local i64.ge_u to fold to a const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(ge_func, @ir.hot_node_get(ge_func, ge_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )
}

///|
test "optimize-instructions folds same-local integer binary operands" {
  let i32_sub = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 local.get 0 i32.sub))",
  )
  let i32_sub_root = @ir.hot_root_get(i32_sub, 0)
  match @ir.hot_node_get(i32_sub, i32_sub_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected same-local i32.sub to fold to zero")
  }
  @debug.assert_eq(
    @ir.hot_const_get(i32_sub, @ir.hot_node_get(i32_sub, i32_sub_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )

  let i64_xor = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i64) local.get 0 local.get 0 i64.xor))",
  )
  let i64_xor_root = @ir.hot_root_get(i64_xor, 0)
  match @ir.hot_node_get(i64_xor, i64_xor_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected same-local i64.xor to fold to zero")
  }
  @debug.assert_eq(
    @ir.hot_const_get(i64_xor, @ir.hot_node_get(i64_xor, i64_xor_root).imm0),
    @ir.HotConstPayload::i64_const(@lib.I64(0L)),
  )

  let i32_and = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 local.get 0 i32.and))",
  )
  let i32_and_root = @ir.hot_root_get(i32_and, 0)
  match @ir.hot_node_get(i32_and, i32_and_root).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected same-local i32.and to fold to the local")
  }
  @debug.assert_eq(@ir.hot_node_get(i32_and, i32_and_root).imm0, 0)

  let i64_or = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i64) local.get 0 local.get 0 i64.or))",
  )
  let i64_or_root = @ir.hot_root_get(i64_or, 0)
  match @ir.hot_node_get(i64_or, i64_or_root).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected same-local i64.or to fold to the local")
  }
  @debug.assert_eq(@ir.hot_node_get(i64_or, i64_or_root).imm0, 0)
}

///|
test "optimize-instructions folds i32 masked unsigned compares outside max" {
  let eq_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 255 i32.and i32.const 256 i32.eq))",
  )
  let eq_root = @ir.hot_root_get(eq_func, 0)
  match @ir.hot_node_get(eq_func, eq_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected i32 masked impossible eq to fold to a const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(eq_func, @ir.hot_node_get(eq_func, eq_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )

  let ne_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 255 i32.and i32.const 256 i32.ne))",
  )
  let ne_root = @ir.hot_root_get(ne_func, 0)
  match @ir.hot_node_get(ne_func, ne_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected i32 masked impossible ne to fold to a const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(ne_func, @ir.hot_node_get(ne_func, ne_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )

  let lt_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 255 i32.and i32.const 256 i32.lt_u))",
  )
  let lt_root = @ir.hot_root_get(lt_func, 0)
  match @ir.hot_node_get(lt_func, lt_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected i32 masked lt_u above max to fold to a const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(lt_func, @ir.hot_node_get(lt_func, lt_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )

  let ge_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 255 i32.and i32.const -1 i32.ge_u))",
  )
  let ge_root = @ir.hot_root_get(ge_func, 0)
  match @ir.hot_node_get(ge_func, ge_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected i32 masked ge_u above max to fold to a const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(ge_func, @ir.hot_node_get(ge_func, ge_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )
}

///|
test "optimize-instructions folds i32 unsigned-shift bounded compares" {
  let eq_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 8 i32.shr_u i32.const 16777216 i32.eq))",
  )
  let eq_root = @ir.hot_root_get(eq_func, 0)
  match @ir.hot_node_get(eq_func, eq_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected i32 shr_u bounded impossible eq to fold to a const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(eq_func, @ir.hot_node_get(eq_func, eq_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )

  let lt_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 8 i32.shr_u i32.const 16777216 i32.lt_u))",
  )
  let lt_root = @ir.hot_root_get(lt_func, 0)
  match @ir.hot_node_get(lt_func, lt_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected i32 shr_u bounded lt_u above max to fold to a const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(lt_func, @ir.hot_node_get(lt_func, lt_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )

  let source =
    #|(module
    #|  (func $test (result i32)
    #|    call $effect
    #|    i32.const 8
    #|    i32.shr_u
    #|    i32.const 16777216
    #|    i32.eq)
    #|  (func $effect (result i32) i32.const 7))
    #|
  let effect_func = optimize_instructions_test_run_hot(source)
  let root = @ir.hot_root_get(effect_func, 0)
  match @ir.hot_node_get(effect_func, root).op {
    @ir.HotOp::Block => ()
    _ => fail("expected effectful i32 shr_u compare to become drop+const block")
  }
  let body = @ir.hot_region_body_ref(effect_func, root)
  @debug.assert_eq(@ir.hot_region_root_count(effect_func, body), 2)
  let dropped = @ir.hot_region_get(effect_func, body, 0)
  match @ir.hot_node_get(effect_func, dropped).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected first folded i32 shr_u compare root to preserve lhs")
  }
  @debug.assert_eq(@ir.hot_child_count(effect_func, dropped), 1)
  let shifted = @ir.hot_child_get(effect_func, dropped, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(effect_func, shifted),
    Some(@lib.Instruction::i32_shr_u()),
  )
  let result = @ir.hot_region_get(effect_func, body, 1)
  match @ir.hot_node_get(effect_func, result).op {
    @ir.HotOp::Const => ()
    _ => fail("expected second folded i32 shr_u compare root to be const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(effect_func, @ir.hot_node_get(effect_func, result).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )
}

///|
test "optimize-instructions folds i32 sign-extension equality outside range" {
  let eq8_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.extend8_s i32.const 128 i32.eq))",
  )
  let eq8_root = @ir.hot_root_get(eq8_func, 0)
  match @ir.hot_node_get(eq8_func, eq8_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected i32.extend8_s equality above range to fold to const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(eq8_func, @ir.hot_node_get(eq8_func, eq8_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )

  let ne16_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.extend16_s i32.const -32769 i32.ne))",
  )
  let ne16_root = @ir.hot_root_get(ne16_func, 0)
  match @ir.hot_node_get(ne16_func, ne16_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected i32.extend16_s inequality below range to fold to const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(ne16_func, @ir.hot_node_get(ne16_func, ne16_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )

  let effect_source =
    #|(module
    #|  (func $test (result i32)
    #|    call $effect
    #|    i32.extend8_s
    #|    i32.const 128
    #|    i32.eq)
    #|  (func $effect (result i32) i32.const 7))
    #|
  let effect_func = optimize_instructions_test_run_hot(effect_source)
  let effect_root = @ir.hot_root_get(effect_func, 0)
  match @ir.hot_node_get(effect_func, effect_root).op {
    @ir.HotOp::Block => ()
    _ => fail("expected effectful sign-extension equality to preserve effects")
  }
  let body = @ir.hot_region_body_ref(effect_func, effect_root)
  @debug.assert_eq(@ir.hot_region_root_count(effect_func, body), 2)
  let dropped = @ir.hot_region_get(effect_func, body, 0)
  match @ir.hot_node_get(effect_func, dropped).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected folded sign-extension equality to drop effectful input")
  }
  let result = @ir.hot_region_get(effect_func, body, 1)
  match @ir.hot_node_get(effect_func, result).op {
    @ir.HotOp::Const => ()
    _ => fail("expected folded sign-extension equality result to be const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(effect_func, @ir.hot_node_get(effect_func, result).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )
}

///|
test "optimize-instructions keeps i64 sign-extension equality outside range" {
  // Boundary-only OI-D classification: Binaryen `version_130`
  // `--optimize-instructions` keeps i64 sign-extension equality/inequality
  // comparisons even when the constant is outside the signed lane range
  // (`.tmp/oi-d-i64-signext-equality-probe.wat`). Starshine likewise keeps
  // these forms rather than generalizing the covered i32 range fold.
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (export "eq8") (param i64) (result i32)
        #|    local.get 0
        #|    i64.extend8_s
        #|    i64.const 128
        #|    i64.eq)
        #|  (func (export "ne16") (param i64) (result i32)
        #|    local.get 0
        #|    i64.extend16_s
        #|    i64.const -32769
        #|    i64.ne)
        #|  (func (export "eq32") (param i64) (result i32)
        #|    local.get 0
        #|    i64.extend32_s
        #|    i64.const 2147483648
        #|    i64.eq))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected i64 sign-extension equality boundary success, got \{err}")
  }
  let eq8_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(eq8_pretty.contains("i64.eq"), msg=eq8_pretty)
  assert_true(eq8_pretty.contains("i64.extend8s"), msg=eq8_pretty)
  assert_true(eq8_pretty.contains("I64(128)"), msg=eq8_pretty)
  let ne16_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(ne16_pretty.contains("i64.ne"), msg=ne16_pretty)
  assert_true(ne16_pretty.contains("i64.extend16s"), msg=ne16_pretty)
  assert_true(ne16_pretty.contains("I64(-32769)"), msg=ne16_pretty)
  let eq32_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(eq32_pretty.contains("i64.eq"), msg=eq32_pretty)
  assert_true(eq32_pretty.contains("i64.extend32s"), msg=eq32_pretty)
  assert_true(eq32_pretty.contains("I64(2147483648)"), msg=eq32_pretty)
}

///|
test "optimize-instructions keeps i32 sign-extension relational compares outside range" {
  // Boundary-only OI-D classification: Binaryen `version_130`
  // `--optimize-instructions` keeps signed relational comparisons over direct
  // i32 sign-extension results even when the constant lies outside the signed
  // lane range (`.tmp/oi-d-i32-signext-rel-boundary-probe.wat`). Starshine
  // only claims equality/inequality folds for this source-backed subset.
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (export "lt8") (param i32) (result i32)
        #|    local.get 0
        #|    i32.extend8_s
        #|    i32.const 128
        #|    i32.lt_s)
        #|  (func (export "gt16") (param i32) (result i32)
        #|    local.get 0
        #|    i32.extend16_s
        #|    i32.const -32769
        #|    i32.gt_s))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected i32 sign-extension relational boundary success, got \{err}",
      )
  }
  let lt8_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(lt8_pretty.contains("i32.lt_s"), msg=lt8_pretty)
  assert_true(lt8_pretty.contains("i32.extend8s"), msg=lt8_pretty)
  assert_true(lt8_pretty.contains("I32(128)"), msg=lt8_pretty)
  let gt16_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(gt16_pretty.contains("i32.gt_s"), msg=gt16_pretty)
  assert_true(gt16_pretty.contains("i32.extend16s"), msg=gt16_pretty)
  assert_true(gt16_pretty.contains("I32(-32769)"), msg=gt16_pretty)
}

///|
test "optimize-instructions preserves i32 masked unsigned compare effects" {
  let source =
    #|(module
    #|  (func $test (result i32)
    #|    call $effect
    #|    i32.const 255
    #|    i32.and
    #|    i32.const 256
    #|    i32.eq)
    #|  (func $effect (result i32) i32.const 7))
    #|
  let func = optimize_instructions_test_run_hot(source)
  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block => ()
    _ =>
      fail("expected effectful i32 masked compare to become drop+const block")
  }
  let body = @ir.hot_region_body_ref(func, root)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 2)
  let dropped = @ir.hot_region_get(func, body, 0)
  match @ir.hot_node_get(func, dropped).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected first folded i32 masked compare root to preserve lhs with drop",
      )
  }
  @debug.assert_eq(@ir.hot_child_count(func, dropped), 1)
  let masked = @ir.hot_child_get(func, dropped, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, masked),
    Some(@lib.Instruction::i32_and()),
  )
  let result = @ir.hot_region_get(func, body, 1)
  match @ir.hot_node_get(func, result).op {
    @ir.HotOp::Const => ()
    _ => fail("expected second folded i32 masked compare root to be const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, result).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )
}

///|
test "optimize-instructions folds i64 masked unsigned compares outside max" {
  let eq_func = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i32) local.get 0 i64.const 255 i64.and i64.const 256 i64.eq))",
  )
  let eq_root = @ir.hot_root_get(eq_func, 0)
  match @ir.hot_node_get(eq_func, eq_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected i64 masked impossible eq to fold to a const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(eq_func, @ir.hot_node_get(eq_func, eq_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )

  let ne_func = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i32) local.get 0 i64.const 255 i64.and i64.const 256 i64.ne))",
  )
  let ne_root = @ir.hot_root_get(ne_func, 0)
  match @ir.hot_node_get(ne_func, ne_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected i64 masked impossible ne to fold to a const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(ne_func, @ir.hot_node_get(ne_func, ne_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )

  let lt_func = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i32) local.get 0 i64.const 255 i64.and i64.const 256 i64.lt_u))",
  )
  let lt_root = @ir.hot_root_get(lt_func, 0)
  match @ir.hot_node_get(lt_func, lt_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected i64 masked lt_u above max to fold to a const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(lt_func, @ir.hot_node_get(lt_func, lt_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )

  let ge_func = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i32) local.get 0 i64.const 255 i64.and i64.const -1 i64.ge_u))",
  )
  let ge_root = @ir.hot_root_get(ge_func, 0)
  match @ir.hot_node_get(ge_func, ge_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected i64 masked ge_u above max to fold to a const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(ge_func, @ir.hot_node_get(ge_func, ge_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )
}

///|
test "optimize-instructions folds i64 unsigned-shift bounded compares" {
  let eq_func = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i32) local.get 0 i64.const 8 i64.shr_u i64.const 72057594037927936 i64.eq))",
  )
  let eq_root = @ir.hot_root_get(eq_func, 0)
  match @ir.hot_node_get(eq_func, eq_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected i64 shr_u bounded impossible eq to fold to a const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(eq_func, @ir.hot_node_get(eq_func, eq_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )

  let lt_func = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i32) local.get 0 i64.const 8 i64.shr_u i64.const 72057594037927936 i64.lt_u))",
  )
  let lt_root = @ir.hot_root_get(lt_func, 0)
  match @ir.hot_node_get(lt_func, lt_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected i64 shr_u bounded lt_u above max to fold to a const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(lt_func, @ir.hot_node_get(lt_func, lt_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )

  let source =
    #|(module
    #|  (func $test (result i32)
    #|    call $effect
    #|    i64.const 8
    #|    i64.shr_u
    #|    i64.const 72057594037927936
    #|    i64.eq)
    #|  (func $effect (result i64) i64.const 7))
    #|
  let effect_func = optimize_instructions_test_run_hot(source)
  let root = @ir.hot_root_get(effect_func, 0)
  match @ir.hot_node_get(effect_func, root).op {
    @ir.HotOp::Block => ()
    _ => fail("expected effectful i64 shr_u compare to become drop+const block")
  }
  let body = @ir.hot_region_body_ref(effect_func, root)
  @debug.assert_eq(@ir.hot_region_root_count(effect_func, body), 2)
  let dropped = @ir.hot_region_get(effect_func, body, 0)
  match @ir.hot_node_get(effect_func, dropped).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected first folded i64 shr_u compare root to preserve lhs")
  }
  @debug.assert_eq(@ir.hot_child_count(effect_func, dropped), 1)
  let shifted = @ir.hot_child_get(effect_func, dropped, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(effect_func, shifted),
    Some(@lib.Instruction::i64_shr_u()),
  )
  let result = @ir.hot_region_get(effect_func, body, 1)
  match @ir.hot_node_get(effect_func, result).op {
    @ir.HotOp::Const => ()
    _ => fail("expected second folded i64 shr_u compare root to be const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(effect_func, @ir.hot_node_get(effect_func, result).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )
}

///|
test "optimize-instructions folds recursive unsigned maxBits compares" {
  let i32_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 1023 i32.and i32.const 4 i32.shr_u i32.const 64 i32.eq))",
  )
  let i32_root = @ir.hot_root_get(i32_func, 0)
  match @ir.hot_node_get(i32_func, i32_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected nested i32 and/shr_u maxBits eq to fold to a const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(i32_func, @ir.hot_node_get(i32_func, i32_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )

  let i64_func = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i32) local.get 0 i64.const 1023 i64.and i64.const 4 i64.shr_u i64.const 64 i64.eq))",
  )
  let i64_root = @ir.hot_root_get(i64_func, 0)
  match @ir.hot_node_get(i64_func, i64_root).op {
    @ir.HotOp::Const => ()
    _ => fail("expected nested i64 and/shr_u maxBits eq to fold to a const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(i64_func, @ir.hot_node_get(i64_func, i64_root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )

  let source =
    #|(module
    #|  (func $test (result i32)
    #|    call $effect
    #|    i32.const 1023
    #|    i32.and
    #|    i32.const 4
    #|    i32.shr_u
    #|    i32.const 64
    #|    i32.eq)
    #|  (func $effect (result i32) i32.const 7))
    #|
  let effect_func = optimize_instructions_test_run_hot(source)
  let root = @ir.hot_root_get(effect_func, 0)
  match @ir.hot_node_get(effect_func, root).op {
    @ir.HotOp::Block => ()
    _ => fail("expected recursive maxBits compare to become drop+const block")
  }
  let body = @ir.hot_region_body_ref(effect_func, root)
  @debug.assert_eq(@ir.hot_region_root_count(effect_func, body), 2)
  let dropped = @ir.hot_region_get(effect_func, body, 0)
  match @ir.hot_node_get(effect_func, dropped).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected recursive maxBits fold to preserve lhs with a drop")
  }
  let shifted = @ir.hot_child_get(effect_func, dropped, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(effect_func, shifted),
    Some(@lib.Instruction::i32_shr_u()),
  )
  let masked = @ir.hot_child_get(effect_func, shifted, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(effect_func, masked),
    Some(@lib.Instruction::i32_and()),
  )
  let result = @ir.hot_region_get(effect_func, body, 1)
  match @ir.hot_node_get(effect_func, result).op {
    @ir.HotOp::Const => ()
    _ => fail("expected recursive maxBits folded result to be const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(effect_func, @ir.hot_node_get(effect_func, result).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )
}

///|
test "optimize-instructions folds unsigned load maxBits compares" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $load8 (param $ptr i32) (result i32)
    #|    local.get $ptr
    #|    i32.load8_u
    #|    i32.const 256
    #|    i32.eq)
    #|  (func $load16 (result i32)
    #|    call $effect
    #|    i32.load16_u
    #|    i32.const 65536
    #|    i32.eq)
    #|  (func $effect (result i32) i32.const 0))
    #|
  let load8_func = optimize_instructions_test_run_hot(source)
  let load8_root = @ir.hot_root_get(load8_func, 0)
  match @ir.hot_node_get(load8_func, load8_root).op {
    @ir.HotOp::Block => ()
    _ => fail("expected load8_u maxBits compare to preserve load as drop+const")
  }
  let load8_body = @ir.hot_region_body_ref(load8_func, load8_root)
  @debug.assert_eq(@ir.hot_region_root_count(load8_func, load8_body), 2)
  let load8_drop = @ir.hot_region_get(load8_func, load8_body, 0)
  match @ir.hot_node_get(load8_func, load8_drop).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected load8_u maxBits fold to preserve load with a drop")
  }
  @debug.assert_eq(
    @ir.hot_node_exact_instr(
      load8_func,
      @ir.hot_child_get(load8_func, load8_drop, 0),
    ),
    Some(
      @lib.Instruction::i32_load8u(
        @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0)),
      ),
    ),
  )
  let load8_result = @ir.hot_region_get(load8_func, load8_body, 1)
  @debug.assert_eq(
    @ir.hot_const_get(
      load8_func,
      @ir.hot_node_get(load8_func, load8_result).imm0,
    ),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )

  let load16_source =
    #|(module
    #|  (memory 1)
    #|  (func $test (result i32)
    #|    call $effect
    #|    i32.load16_u
    #|    i32.const 65536
    #|    i32.eq)
    #|  (func $effect (result i32) i32.const 0))
    #|
  let load16_func = optimize_instructions_test_run_hot(load16_source)
  let load16_root = @ir.hot_root_get(load16_func, 0)
  match @ir.hot_node_get(load16_func, load16_root).op {
    @ir.HotOp::Block => ()
    _ =>
      fail(
        "expected load16_u maxBits compare to preserve effectful load as drop+const",
      )
  }
  let load16_body = @ir.hot_region_body_ref(load16_func, load16_root)
  @debug.assert_eq(@ir.hot_region_root_count(load16_func, load16_body), 2)
  let load16_drop = @ir.hot_region_get(load16_func, load16_body, 0)
  match @ir.hot_node_get(load16_func, load16_drop).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected load16_u maxBits fold to preserve load with a drop")
  }
  @debug.assert_eq(
    @ir.hot_node_exact_instr(
      load16_func,
      @ir.hot_child_get(load16_func, load16_drop, 0),
    ),
    Some(
      @lib.Instruction::i32_load16u(
        @lib.MemArg::new(@lib.U32(1), None, @lib.U64(0)),
      ),
    ),
  )
  let load16_result = @ir.hot_region_get(load16_func, load16_body, 1)
  @debug.assert_eq(
    @ir.hot_const_get(
      load16_func,
      @ir.hot_node_get(load16_func, load16_result).imm0,
    ),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )
}

///|
test "optimize-instructions preserves i64 masked unsigned compare effects" {
  let source =
    #|(module
    #|  (func $test (result i32)
    #|    call $effect
    #|    i64.const 255
    #|    i64.and
    #|    i64.const 256
    #|    i64.eq)
    #|  (func $effect (result i64) i64.const 7))
    #|
  let func = optimize_instructions_test_run_hot(source)
  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block => ()
    _ =>
      fail("expected effectful i64 masked compare to become drop+const block")
  }
  let body = @ir.hot_region_body_ref(func, root)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 2)
  let dropped = @ir.hot_region_get(func, body, 0)
  match @ir.hot_node_get(func, dropped).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected first folded i64 masked compare root to preserve lhs with drop",
      )
  }
  @debug.assert_eq(@ir.hot_child_count(func, dropped), 1)
  let masked = @ir.hot_child_get(func, dropped, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, masked),
    Some(@lib.Instruction::i64_and()),
  )
  let result = @ir.hot_region_get(func, body, 1)
  match @ir.hot_node_get(func, result).op {
    @ir.HotOp::Const => ()
    _ => fail("expected second folded i64 masked compare root to be const")
  }
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, result).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(0)),
  )
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
test "optimize-instructions canonicalizes leading positive const adds" {
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
    @ir.HotOp::LocalGet => ()
    _ => fail("expected non-constant positive add operand to move to the lhs")
  }
  let rhs_node = @ir.hot_node_get(func, rhs)
  match rhs_node.op {
    @ir.HotOp::Const => ()
    _ => fail("expected leading positive add const to move to the rhs")
  }
  @debug.assert_eq(
    @ir.hot_const_get(func, rhs_node.imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(64)),
  )
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
test "optimize-instructions rewrites add with leading zero-sub into sub" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) i32.const 0 local.get 0 i32.sub local.get 1 i32.add))",
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
    _ => fail("expected (0 - x) + y rewrite to y - x")
  }
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected (0 - x) + y rewrite to y - x")
  }
}

///|
/// Integer negation can be moved out of a product: `(-x) * (-y)` rewrites to
/// `x * y`. The rewrite strips both `(0 - operand)` wrappers in place without
/// reordering the operands, so it applies even when an operand carries effects
/// (e.g. a `call`), as long as both factors are negated the same way.
test "optimize-instructions normalizes integer mul negation" {
  let mul_func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) i32.const 0 local.get 0 i32.sub i32.const 0 local.get 1 i32.sub i32.mul))",
  )
  let mul_root = @ir.hot_root_get(mul_func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(mul_func, mul_root),
    Some(@lib.Instruction::i32_mul()),
  )
  match
    @ir.hot_node_get(mul_func, @ir.hot_child_get(mul_func, mul_root, 0)).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected (-x) * (-y) rewrite to x * y")
  }
  match
    @ir.hot_node_get(mul_func, @ir.hot_child_get(mul_func, mul_root, 1)).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected (-x) * (-y) rewrite to x * y")
  }

  let i64_mul_func = optimize_instructions_test_run_hot(
    "(module (func (param i64 i64) (result i64) i64.const 0 local.get 0 i64.sub i64.const 0 local.get 1 i64.sub i64.mul))",
  )
  let i64_mul_root = @ir.hot_root_get(i64_mul_func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(i64_mul_func, i64_mul_root),
    Some(@lib.Instruction::i64_mul()),
  )

  // Effectful operands still rewrite because the negation is stripped in place
  // rather than reordered: `(0 - call) * (0 - y)` becomes `call * y`.
  let effect_mul_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) i32.const 0 call 1 i32.sub i32.const 0 local.get 0 i32.sub i32.mul) (func (result i32) i32.const 1))",
  )
  let effect_mul_root = @ir.hot_root_get(effect_mul_func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(effect_mul_func, effect_mul_root),
    Some(@lib.Instruction::i32_mul()),
  )
  match
    @ir.hot_node_get(
      effect_mul_func,
      @ir.hot_child_get(effect_mul_func, effect_mul_root, 0),
    ).op {
    @ir.HotOp::Call => ()
    _ => fail("expected effectful (-call) * (-y) to keep the call operand")
  }
}

///|
test "optimize-instructions canonicalizes commutative call operands when safe" {
  let local_call_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 call 1 i32.add) (func (result i32) i32.const 1))",
  )
  let local_call_root = @ir.hot_root_get(local_call_func, 0)
  match
    @ir.hot_node_get(
      local_call_func,
      @ir.hot_child_get(local_call_func, local_call_root, 0),
    ).op {
    @ir.HotOp::Call => ()
    _ => fail("expected safe local.get + call to canonicalize with call first")
  }
  match
    @ir.hot_node_get(
      local_call_func,
      @ir.hot_child_get(local_call_func, local_call_root, 1),
    ).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected local.get to move behind call")
  }

  let const_call_func = optimize_instructions_test_run_hot(
    "(module (func (result i32) i32.const 5 call 1 i32.mul) (func (result i32) i32.const 1))",
  )
  let const_call_root = @ir.hot_root_get(const_call_func, 0)
  match
    @ir.hot_node_get(
      const_call_func,
      @ir.hot_child_get(const_call_func, const_call_root, 0),
    ).op {
    @ir.HotOp::Call => ()
    _ => fail("expected safe const + call to canonicalize with call first")
  }

  let neg_mul_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) i32.const 0 local.get 0 i32.sub i32.const 0 call 1 i32.sub i32.mul) (func (result i32) i32.const 1))",
  )
  let neg_mul_root = @ir.hot_root_get(neg_mul_func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(neg_mul_func, neg_mul_root),
    Some(@lib.Instruction::i32_mul()),
  )
  match
    @ir.hot_node_get(
      neg_mul_func,
      @ir.hot_child_get(neg_mul_func, neg_mul_root, 0),
    ).op {
    @ir.HotOp::Call => ()
    _ =>
      fail("expected post-negation mul factors to canonicalize with call first")
  }

  let call_indirect_func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[]),
  )
  let call_indirect = @ir.hot_build_call_indirect(
    call_indirect_func,
    @lib.TypeIdx::new(0U),
    @lib.TableIdx::new(0U),
    [@lib.ValType::i32()],
    [],
    @ir.hot_build_const_i32(call_indirect_func, @lib.I32(0)),
  )
  let indirect_add = @ir.hot_build_binary(
    call_indirect_func,
    @lib.ValType::i32(),
    @ir.hot_build_local_get(call_indirect_func, 0),
    call_indirect,
  )
  @ir.hot_node_exact_instr_set(
    call_indirect_func,
    indirect_add,
    @lib.Instruction::i32_add(),
  )
  @ir.hot_root_append(call_indirect_func, indirect_add)
  let indirect_ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(indirect_ctx, call_indirect_func) {
    Ok(_) => ()
    Err(err) => fail("expected call_indirect commutative success, got \{err}")
  }
  match
    @ir.hot_node_get(
      call_indirect_func,
      @ir.hot_child_get(call_indirect_func, indirect_add, 0),
    ).op {
    @ir.HotOp::CallIndirect => ()
    _ => fail("expected safe local.get + call_indirect to canonicalize first")
  }

  let call_ref_func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(
      params=[@lib.ValType::i32(), @lib.ValType::funcref()],
      locals=[],
    ),
  )
  let call_ref = @ir.hot_build_call_ref(
    call_ref_func,
    @lib.TypeIdx::new(0U),
    [@lib.ValType::i32()],
    [],
    @ir.hot_build_local_get(call_ref_func, 1),
  )
  let call_ref_add = @ir.hot_build_binary(
    call_ref_func,
    @lib.ValType::i32(),
    @ir.hot_build_local_get(call_ref_func, 0),
    call_ref,
  )
  @ir.hot_node_exact_instr_set(
    call_ref_func,
    call_ref_add,
    @lib.Instruction::i32_add(),
  )
  @ir.hot_root_append(call_ref_func, call_ref_add)
  let call_ref_ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(call_ref_ctx, call_ref_func) {
    Ok(_) => ()
    Err(err) => fail("expected call_ref commutative success, got \{err}")
  }
  match
    @ir.hot_node_get(
      call_ref_func,
      @ir.hot_child_get(call_ref_func, call_ref_add, 0),
    ).op {
    @ir.HotOp::CallRef => ()
    _ => fail("expected safe local.get + call_ref to canonicalize first")
  }
}

///|
test "optimize-instructions keeps commutative call operands when reorder is unsafe" {
  let load_call_func = optimize_instructions_test_run_hot(
    "(module (memory 1) (func (param i32) (result i32) local.get 0 i32.load call 1 i32.add) (func (result i32) i32.const 1))",
  )
  let load_call_root = @ir.hot_root_get(load_call_func, 0)
  match
    @ir.hot_node_get(
      load_call_func,
      @ir.hot_child_get(load_call_func, load_call_root, 0),
    ).op {
    @ir.HotOp::Load => ()
    _ => fail("expected load to stay before call across memory conflict")
  }
  match
    @ir.hot_node_get(
      load_call_func,
      @ir.hot_child_get(load_call_func, load_call_root, 1),
    ).op {
    @ir.HotOp::Call => ()
    _ => fail("expected call to stay behind load across memory conflict")
  }

  let tee_call_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) (local i32) local.get 0 local.tee 1 call 1 i32.add) (func (result i32) i32.const 1))",
  )
  let tee_call_root = @ir.hot_root_get(tee_call_func, 0)
  match
    @ir.hot_node_get(
      tee_call_func,
      @ir.hot_child_get(tee_call_func, tee_call_root, 0),
    ).op {
    @ir.HotOp::LocalTee => ()
    _ => fail("expected local.tee to stay before may-trapping call")
  }
  match
    @ir.hot_node_get(
      tee_call_func,
      @ir.hot_child_get(tee_call_func, tee_call_root, 1),
    ).op {
    @ir.HotOp::Call => ()
    _ => fail("expected call to stay behind side-effecting local.tee")
  }
}

///|
/// With the sound reorder guard, a `(0 - x)` zero-sub operand whose only
/// effects are reads (a `call` reads globals/memory/tables but never the
/// caller's locals) can swap past a `local.get`, so the leading
/// `(0 - x) + y => y - x` and trailing `x + (0 - y) => x - y` rewrites fire.
/// The trailing path needs no reorder check (operands stay in order); the
/// leading path is gated by the new guard.
test "optimize-instructions rewrites add/sub with effectful zero-sub operand" {
  // Leading: `(0 - call 1) + local.get 0`. The call reads opaque state but does
  // not conflict with the local read, so it reorders to `local.get 0 - call 1`.
  let leading_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) i32.const 0 call 1 i32.sub local.get 0 i32.add) (func (result i32) i32.const 1))",
  )
  let leading_root = @ir.hot_root_get(leading_func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(leading_func, leading_root),
    Some(@lib.Instruction::i32_sub()),
  )
  // Trailing: `local.get 0 + (0 - call 1)`. No reorder is needed.
  let trailing_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 0 call 1 i32.sub i32.add) (func (result i32) i32.const 1))",
  )
  let trailing_root = @ir.hot_root_get(trailing_func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(trailing_func, trailing_root),
    Some(@lib.Instruction::i32_sub()),
  )
}

///|
/// The leading `(0 - x) + y => y - x` rewrite reorders `x` and `y`, so it must
/// be blocked whenever the reorder would change observable behavior. These
/// cases pin the soundness guard that Binaryen matches: a same-region
/// read/write conflict, a memory write vs read, and a may-trap read vs a
/// side-effecting operand all keep the `add`.
test "optimize-instructions keeps leading zero-sub add when reorder is unsafe" {
  // `(0 - local.tee 0) + local.get 0`: the tee writes local 0, the get reads it.
  let local_conflict = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) i32.const 0 local.get 1 local.tee 0 i32.sub local.get 0 i32.add))",
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(
      local_conflict,
      @ir.hot_root_get(local_conflict, 0),
    ),
    Some(@lib.Instruction::i32_add()),
  )
  // `(0 - memory.grow) + i32.load`: the grow writes memory, the load reads it.
  let memory_conflict = optimize_instructions_test_run_hot(
    "(module (memory 1) (func (param i32) (result i32) i32.const 0 i32.const 0 memory.grow i32.sub local.get 0 i32.load offset=0 i32.add))",
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(
      memory_conflict,
      @ir.hot_root_get(memory_conflict, 0),
    ),
    Some(@lib.Instruction::i32_add()),
  )
  // `(0 - i32.load) + local.tee 0`: disjoint regions, but the load may trap and
  // the tee has a side effect, so reordering could expose the tee before a trap.
  let trap_conflict = optimize_instructions_test_run_hot(
    "(module (memory 1) (func (param i32 i32) (result i32) i32.const 0 local.get 0 i32.load offset=0 i32.sub local.get 1 local.tee 0 i32.add))",
  )
  @debug.assert_eq(
    @ir.hot_node_exact_instr(trap_conflict, @ir.hot_root_get(trap_conflict, 0)),
    Some(@lib.Instruction::i32_add()),
  )
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

  // Binaryen version_130 keeps add/mul with 0/1 but canonicalizes negation and
  // divide-by-one spellings. Signed-zero boundaries stay out of scope here.
  let f32_mul_neg = optimize_instructions_test_run_hot(
    "(module (func (param f32) (result f32) local.get 0 f32.const -1 f32.mul))",
  )
  let f32_mul_neg_root = @ir.hot_root_get(f32_mul_neg, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(f32_mul_neg, f32_mul_neg_root),
    Some(@lib.Instruction::f32_sub()),
  )
  let f32_div_one = optimize_instructions_test_run_hot(
    "(module (func (param f32) (result f32) local.get 0 f32.const 1 f32.div))",
  )
  let f32_div_one_root = @ir.hot_root_get(f32_div_one, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(f32_div_one, f32_div_one_root),
    Some(@lib.Instruction::f32_mul()),
  )
  let f64_div_neg = optimize_instructions_test_run_hot(
    "(module (func (param f64) (result f64) local.get 0 f64.const -1 f64.div))",
  )
  let f64_div_neg_root = @ir.hot_root_get(f64_div_neg, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(f64_div_neg, f64_div_neg_root),
    Some(@lib.Instruction::f64_sub()),
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
test "optimize-instructions preserves effectful prefix while folding same-local ref.cast equality" {
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let struct_heap = @lib.HeapType::abs(@lib.AbsHeapType::struct_())
  let eq_ref = @lib.ValType::ref_null(eq_heap)
  let struct_ref = @lib.ValType::ref_null(struct_heap)
  let effect_type = @lib.TypeIdx::new(0U)
  let eq_func_type = @lib.TypeIdx::new(1U)
  let struct_func_type = @lib.TypeIdx::new(2U)
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
            @lib.CompType::func([eq_ref], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([struct_ref], [@lib.ValType::i32()]),
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
    .with_func_sec(
      @lib.FuncSec::new([
        eq_func_type, eq_func_type, struct_func_type, struct_func_type,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(true, eq_heap),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_eq(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(true, eq_heap),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(true, eq_heap),
            @lib.Instruction::ref_eq(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(true, eq_heap),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_eq(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
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
  for func_idx in 1U..<5U {
    let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(func_idx))
    assert_false(pretty.contains("ref.eq"), msg=pretty)
    assert_false(pretty.contains("ref.cast"), msg=pretty)
    assert_true(pretty.contains("call (Func 0)"), msg=pretty)
    assert_true(pretty.contains("drop"), msg=pretty)
    assert_true(pretty.contains("I32(1)"), msg=pretty)
  }
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
test "optimize-instructions preserves effectful prefix while folding self ref.eq" {
  let source =
    #|(module
    #|  (import "m" "effect" (func $effect (result i32)))
    #|  (func (export "nullable") (param eqref) (result i32)
    #|    call $effect
    #|    drop
    #|    local.get 0
    #|    local.get 0
    #|    ref.eq)
    #|  (func (export "non-null") (param (ref eq)) (result i32)
    #|    call $effect
    #|    drop
    #|    local.get 0
    #|    local.get 0
    #|    ref.eq)
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected effectful self ref.eq optimize success, got \{err}")
  }
  let nullable_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let non_null_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(nullable_pretty.contains("ref.eq"), msg=nullable_pretty)
  assert_false(non_null_pretty.contains("ref.eq"), msg=non_null_pretty)
  assert_true(nullable_pretty.contains("call (Func 0)"), msg=nullable_pretty)
  assert_true(non_null_pretty.contains("call (Func 0)"), msg=non_null_pretty)
  assert_true(nullable_pretty.contains("drop"), msg=nullable_pretty)
  assert_true(non_null_pretty.contains("drop"), msg=non_null_pretty)
  assert_true(nullable_pretty.contains("I32(1)"), msg=nullable_pretty)
  assert_true(non_null_pretty.contains("I32(1)"), msg=non_null_pretty)
}

///|
test "optimize-instructions preserves effectful prefix while folding struct array ref.eq miss" {
  let source =
    #|(module
    #|  (import "m" "effect" (func $effect (result i32)))
    #|  (func (export "left-non-null") (param (ref struct)) (param (ref null array)) (result i32)
    #|    call $effect
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    ref.eq)
    #|  (func (export "right-non-null") (param (ref null struct)) (param (ref array)) (result i32)
    #|    call $effect
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    ref.eq)
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected effectful struct/array ref.eq miss optimize success, got \{err}",
      )
  }
  let left_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let right_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(left_pretty.contains("ref.eq"), msg=left_pretty)
  assert_false(right_pretty.contains("ref.eq"), msg=right_pretty)
  assert_true(left_pretty.contains("call (Func 0)"), msg=left_pretty)
  assert_true(right_pretty.contains("call (Func 0)"), msg=right_pretty)
  assert_true(left_pretty.contains("drop"), msg=left_pretty)
  assert_true(right_pretty.contains("drop"), msg=right_pretty)
  assert_true(left_pretty.contains("I32(0)"), msg=left_pretty)
  assert_true(right_pretty.contains("I32(0)"), msg=right_pretty)
}

///|
test "optimize-instructions preserves effectful prefix while folding same-local ref.i31 equality" {
  let source =
    #|(module
    #|  (import "m" "effect" (func $effect (result i32)))
    #|  (func (export "same-local-i31") (param i32) (result i32)
    #|    call $effect
    #|    drop
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
      fail(
        "expected effectful same-local ref.i31 equality optimize success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("ref.eq"), msg=pretty)
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
}

///|
test "optimize-instructions preserves effectful prefix while folding same-local ref.as_non_null equality" {
  let source =
    #|(module
    #|  (import "m" "effect" (func $effect (result i32)))
    #|  (func (export "left") (param eqref) (result i32)
    #|    call $effect
    #|    drop
    #|    local.get 0
    #|    ref.as_non_null
    #|    local.get 0
    #|    ref.eq)
    #|  (func (export "both") (param eqref) (result i32)
    #|    call $effect
    #|    drop
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
        "expected effectful same-local ref.as_non_null equality optimize success, got \{err}",
      )
  }
  let left_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let both_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(left_pretty.contains("ref.eq"), msg=left_pretty)
  assert_false(both_pretty.contains("ref.eq"), msg=both_pretty)
  assert_true(left_pretty.contains("call (Func 0)"), msg=left_pretty)
  assert_true(both_pretty.contains("call (Func 0)"), msg=both_pretty)
  assert_true(left_pretty.contains("drop"), msg=left_pretty)
  assert_true(both_pretty.contains("drop"), msg=both_pretty)
  assert_true(left_pretty.contains("ref.as_non_null"), msg=left_pretty)
  assert_true(both_pretty.contains("ref.as_non_null"), msg=both_pretty)
  assert_true(left_pretty.contains("I32(1)"), msg=left_pretty)
  assert_true(both_pretty.contains("I32(1)"), msg=both_pretty)
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
test "optimize-instructions preserves effectful ref.i31 operand for impossible equality" {
  let source =
    #|(module
    #|  (type $s (struct))
    #|  (import "m" "effect" (func $effect (result i32)))
    #|  (func (export "right") (param (ref null $s)) (result i32)
    #|    call $effect
    #|    ref.i31
    #|    local.get 0
    #|    ref.eq)
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected effectful impossible i31/struct ref.eq optimize success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("ref.eq"), msg=pretty)
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("I32(0)"), msg=pretty)
}

///|
test "optimize-instructions preserves effectful prefix while folding i31 struct local ref.eq miss" {
  let source =
    #|(module
    #|  (type $s (struct))
    #|  (import "m" "effect" (func $effect (result i32)))
    #|  (func (export "right") (param (ref i31)) (param (ref null $s)) (result i32)
    #|    call $effect
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    ref.eq)
    #|  (func (export "left") (param (ref null $s)) (param (ref i31)) (result i32)
    #|    call $effect
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    ref.eq)
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected effectful i31/struct local ref.eq miss optimize success, got \{err}",
      )
  }
  let right_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let left_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(right_pretty.contains("ref.eq"), msg=right_pretty)
  assert_false(left_pretty.contains("ref.eq"), msg=left_pretty)
  assert_true(right_pretty.contains("call (Func 0)"), msg=right_pretty)
  assert_true(left_pretty.contains("call (Func 0)"), msg=left_pretty)
  assert_true(right_pretty.contains("drop"), msg=right_pretty)
  assert_true(left_pretty.contains("drop"), msg=left_pretty)
  assert_true(right_pretty.contains("I32(0)"), msg=right_pretty)
  assert_true(left_pretty.contains("I32(0)"), msg=left_pretty)
}

///|
test "optimize-instructions preserves effectful prefix while folding i31 array local ref.eq miss" {
  let source =
    #|(module
    #|  (import "m" "effect" (func $effect (result i32)))
    #|  (func (export "right") (param (ref i31)) (param (ref null array)) (result i32)
    #|    call $effect
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    ref.eq)
    #|  (func (export "left") (param (ref null array)) (param (ref i31)) (result i32)
    #|    call $effect
    #|    drop
    #|    local.get 0
    #|    local.get 1
    #|    ref.eq)
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected effectful i31/array local ref.eq miss optimize success, got \{err}",
      )
  }
  let right_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let left_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(right_pretty.contains("ref.eq"), msg=right_pretty)
  assert_false(left_pretty.contains("ref.eq"), msg=left_pretty)
  assert_true(right_pretty.contains("call (Func 0)"), msg=right_pretty)
  assert_true(left_pretty.contains("call (Func 0)"), msg=left_pretty)
  assert_true(right_pretty.contains("drop"), msg=right_pretty)
  assert_true(left_pretty.contains("drop"), msg=left_pretty)
  assert_true(right_pretty.contains("I32(0)"), msg=right_pretty)
  assert_true(left_pretty.contains("I32(0)"), msg=left_pretty)
}

///|
test "optimize-instructions locks indexed i31 aggregate local ref.eq miss coverage" {
  // Coverage-only audit slice: Binaryen folds these indexed/defined heap
  // disjoint equality proofs, and the existing Starshine proof already handles
  // the narrow local forms. This locks the indexed heap surface explicitly.
  let source =
    #|(module
    #|  (type $s (struct))
    #|  (type $a (array i32))
    #|  (import "m" "effect" (func $effect))
    #|  (func (export "indexed-struct") (param (ref i31)) (param (ref $s)) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    ref.eq)
    #|  (func (export "indexed-array-nullable") (param (ref null $a)) (param (ref i31)) (result i32)
    #|    local.get 0
    #|    local.get 1
    #|    ref.eq)
    #|  (func (export "effect-prefix") (param (ref i31)) (param (ref $a)) (result i32)
    #|    call $effect
    #|    local.get 0
    #|    local.get 1
    #|    ref.eq)
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected indexed i31/aggregate ref.eq miss optimize success, got \{err}",
      )
  }
  let struct_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let array_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let effect_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_false(struct_pretty.contains("ref.eq"), msg=struct_pretty)
  assert_false(array_pretty.contains("ref.eq"), msg=array_pretty)
  assert_false(effect_pretty.contains("ref.eq"), msg=effect_pretty)
  assert_true(struct_pretty.contains("I32(0)"), msg=struct_pretty)
  assert_true(array_pretty.contains("I32(0)"), msg=array_pretty)
  assert_true(effect_pretty.contains("call (Func 0)"), msg=effect_pretty)
  assert_true(effect_pretty.contains("drop"), msg=effect_pretty)
  assert_true(effect_pretty.contains("I32(0)"), msg=effect_pretty)
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
test "optimize-instructions lowers non-null same-heap ref.cast to ref.as_non_null" {
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let array_heap = @lib.HeapType::abs(@lib.AbsHeapType::array())
  let maybe_type = @lib.TypeIdx::new(0U)
  let same_heap_type = @lib.TypeIdx::new(1U)
  let array_type = @lib.TypeIdx::new(2U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::eqref_null()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [
              @lib.ValType::ref_type(@lib.RefType::new(false, eq_heap)),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [
              @lib.ValType::ref_type(@lib.RefType::new(false, array_heap)),
            ]),
          ),
        ),
      ]),
    )
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("m"),
          @lib.Name::from_string("maybe"),
          @lib.ExternType::func(maybe_type),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([same_heap_type, array_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::ref_cast(false, eq_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::ref_cast(false, array_heap),
          ]),
        ),
      ]),
    ),
  )
  let same_heap_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let array_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(same_heap_pretty.contains("ref.cast"), msg=same_heap_pretty)
  assert_true(
    same_heap_pretty.contains("ref.as_non_null"),
    msg=same_heap_pretty,
  )
  assert_true(same_heap_pretty.contains("call (Func 0)"), msg=same_heap_pretty)
  assert_true(array_pretty.contains("ref.cast"), msg=array_pretty)
  assert_true(array_pretty.contains("call (Func 0)"), msg=array_pretty)
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
test "optimize-instructions preserves effectful prefix while folding known-null ref.eq" {
  let source =
    #|(module
    #|  (import "m" "effect" (func $effect (result i32)))
    #|  (func (export "both-null") (result i32)
    #|    call $effect
    #|    drop
    #|    ref.null eq
    #|    ref.null eq
    #|    ref.eq)
    #|  (func (export "left-null") (result i32)
    #|    call $effect
    #|    drop
    #|    ref.null eq
    #|    i32.const 1
    #|    ref.i31
    #|    ref.eq)
    #|  (func (export "right-null") (result i32)
    #|    call $effect
    #|    drop
    #|    i32.const 1
    #|    ref.i31
    #|    ref.null eq
    #|    ref.eq)
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected effectful known-null ref.eq optimize success, got \{err}")
  }
  let both_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let left_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let right_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_false(both_pretty.contains("ref.eq"), msg=both_pretty)
  assert_false(left_pretty.contains("ref.eq"), msg=left_pretty)
  assert_false(right_pretty.contains("ref.eq"), msg=right_pretty)
  assert_true(both_pretty.contains("call (Func 0)"), msg=both_pretty)
  assert_true(left_pretty.contains("call (Func 0)"), msg=left_pretty)
  assert_true(right_pretty.contains("call (Func 0)"), msg=right_pretty)
  assert_true(both_pretty.contains("drop"), msg=both_pretty)
  assert_true(left_pretty.contains("drop"), msg=left_pretty)
  assert_true(right_pretty.contains("drop"), msg=right_pretty)
  assert_true(both_pretty.contains("I32(1)"), msg=both_pretty)
  assert_true(left_pretty.contains("I32(0)"), msg=left_pretty)
  assert_true(right_pretty.contains("I32(0)"), msg=right_pretty)
}

///|
test "optimize-instructions preserves effectful prefix while folding known-null ref.as_non_null" {
  let source =
    #|(module
    #|  (import "m" "effect" (func $effect (result i32)))
    #|  (func (export "f") (result eqref)
    #|    call $effect
    #|    drop
    #|    ref.null eq
    #|    ref.as_non_null)
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected effectful known-null ref.as_non_null optimize success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("ref.as_non_null"), msg=pretty)
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "optimize-instructions preserves effectful prefix while folding known-null ref.test and ref.cast" {
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let non_null_eq_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, eq_heap),
  )
  let effect_type = @lib.TypeIdx::new(0U)
  let test_type = @lib.TypeIdx::new(1U)
  let cast_type = @lib.TypeIdx::new(2U)
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
          @lib.SubType::comp_type(@lib.CompType::func([], [non_null_eq_ref])),
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
            @lib.Instruction::drop(),
            @lib.Instruction::ref_null(eq_heap),
            @lib.Instruction::ref_test(false, eq_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::ref_null(eq_heap),
            @lib.Instruction::ref_cast(false, eq_heap),
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
test "optimize-instructions preserves effectful ref.i31 while folding ref.as_non_null" {
  let source =
    #|(module
    #|  (import "env" "effect" (func $effect (result i32)))
    #|  (func (export "f") (result (ref i31))
    #|    call $effect
    #|    ref.i31
    #|    ref.as_non_null)
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["optimize-instructions"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected effectful ref.as_non_null optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("ref.as_non_null"), msg=pretty)
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("ref.i31"), msg=pretty)
}

///|
test "optimize-instructions intentionally keeps exact ref.cast on inexact locals" {
  // OI-J exactness boundary: Binaryen version_130 keeps exact casts from
  // inexact locals because an inexact `(ref $foo)` value may carry a subtype
  // descriptor at runtime. Removing the cast would both lose the exactness trap
  // and may produce an inexact value for an exact result type.
  let foo_type = @lib.TypeIdx::new(0U)
  let nonnull_type = @lib.TypeIdx::new(1U)
  let nullable_type = @lib.TypeIdx::new(2U)
  let foo_heap = @lib.HeapType::new(foo_type)
  let inexact_foo_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, foo_heap),
  )
  let nullable_inexact_foo_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, foo_heap),
  )
  let exact_foo_ref_type = @lib.RefType::new(false, foo_heap, exact=true)
  let exact_foo_ref = @lib.ValType::ref_type(exact_foo_ref_type)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([inexact_foo_ref], [exact_foo_ref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_inexact_foo_ref], [exact_foo_ref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([nonnull_type, nullable_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast_type(exact_foo_ref_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast_type(exact_foo_ref_type),
          ]),
        ),
      ]),
    ),
  )
  let nonnull_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let nullable_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(nonnull_pretty.contains("ref.cast"), msg=nonnull_pretty)
  assert_true(nullable_pretty.contains("ref.cast"), msg=nullable_pretty)
  assert_true(nonnull_pretty.contains("Exact"), msg=nonnull_pretty)
  assert_true(nullable_pretty.contains("Exact"), msg=nullable_pretty)
}

///|
test "optimize-instructions folds exact ref.cast on already exact locals" {
  // OI-J exactness positive: Binaryen version_130 removes exact casts when the
  // operand is already exactly the target heap. Nullable-to-non-null exact casts
  // still preserve the null trap by becoming ref.as_non_null.
  let foo_type = @lib.TypeIdx::new(0U)
  let nonnull_type = @lib.TypeIdx::new(1U)
  let nullable_to_nonnull_type = @lib.TypeIdx::new(2U)
  let nullable_to_nullable_type = @lib.TypeIdx::new(3U)
  let foo_heap = @lib.HeapType::new(foo_type)
  let exact_foo_ref_type = @lib.RefType::new(false, foo_heap, exact=true)
  let nullable_exact_foo_ref_type = @lib.RefType::new(
    true,
    foo_heap,
    exact=true,
  )
  let exact_foo_ref = @lib.ValType::ref_type(exact_foo_ref_type)
  let nullable_exact_foo_ref = @lib.ValType::ref_type(
    nullable_exact_foo_ref_type,
  )
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::new(false, [], @lib.CompType::struct_([])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([exact_foo_ref], [exact_foo_ref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_exact_foo_ref], [exact_foo_ref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_exact_foo_ref], [
              nullable_exact_foo_ref,
            ]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([
        nonnull_type, nullable_to_nonnull_type, nullable_to_nullable_type,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast_type(exact_foo_ref_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast_type(exact_foo_ref_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast_type(nullable_exact_foo_ref_type),
          ]),
        ),
      ]),
    ),
  )
  let nonnull_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let nullable_to_nonnull_pretty = optimized.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  let nullable_to_nullable_pretty = optimized.pretty_print_func(
    @lib.FuncIdx::new(2U),
  )
  assert_false(nonnull_pretty.contains("ref.cast"), msg=nonnull_pretty)
  assert_true(nonnull_pretty.contains("local.get"), msg=nonnull_pretty)
  assert_false(
    nullable_to_nonnull_pretty.contains("ref.cast"),
    msg=nullable_to_nonnull_pretty,
  )
  assert_true(
    nullable_to_nonnull_pretty.contains("ref.as_non_null"),
    msg=nullable_to_nonnull_pretty,
  )
  assert_false(
    nullable_to_nullable_pretty.contains("ref.cast"),
    msg=nullable_to_nullable_pretty,
  )
  assert_true(
    nullable_to_nullable_pretty.contains("local.get"),
    msg=nullable_to_nullable_pretty,
  )
}

///|
test "optimize-instructions intentionally keeps legacy descriptor equality casts" {
  // Boundary-only OI-J descriptor slice: Binaryen version_130 keeps official
  // two-operand descriptor equality casts under `--enable-custom-descriptors`
  // because the explicit descriptor operand participates in the runtime equality
  // check. Starshine's current HOT lift still models descriptor casts as a
  // legacy unary surface, so this test locks the local fail-closed behavior:
  // do not route descriptor casts through ordinary same-heap ref.cast cleanup.
  let described_type = @lib.TypeIdx::new(0U)
  let nullable_func_type = @lib.TypeIdx::new(2U)
  let nonnull_func_type = @lib.TypeIdx::new(3U)
  let described_heap = @lib.HeapType::new(described_type)
  let nullable_described_ref_type = @lib.RefType::new(true, described_heap)
  let nonnull_described_ref_type = @lib.RefType::new(false, described_heap)
  let nullable_described_ref = @lib.ValType::ref_type(
    nullable_described_ref_type,
  )
  let nonnull_described_ref = @lib.ValType::ref_type(nonnull_described_ref_type)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::group([
          @lib.SubType::comp_type(
            @lib.CompType::struct_([]),
            metadata=@lib.TypeMetadata::new(
              descriptor=Some(@lib.TypeIdx::rec(1)),
            ),
          ),
          @lib.SubType::comp_type(
            @lib.CompType::struct_([]),
            metadata=@lib.TypeMetadata::new(
              describes=Some(@lib.TypeIdx::rec(0)),
            ),
          ),
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_described_ref], [
              nullable_described_ref,
            ]),
          ),
          @lib.SubType::comp_type(
            @lib.CompType::func([nonnull_described_ref], [nonnull_described_ref]),
          ),
        ]),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([nullable_func_type, nonnull_func_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast_desc_eq_type(nullable_described_ref_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast_desc_eq_type(nonnull_described_ref_type),
          ]),
        ),
      ]),
    ),
  )
  let nullable_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let nonnull_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(nullable_pretty.contains("ref.cast_desc_eq"), msg=nullable_pretty)
  assert_true(nonnull_pretty.contains("ref.cast_desc_eq"), msg=nonnull_pretty)
  assert_true(nullable_pretty.contains("local.get"), msg=nullable_pretty)
  assert_true(nonnull_pretty.contains("local.get"), msg=nonnull_pretty)
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
test "optimize-instructions rewrites nullable-source non-null-target ref.test to null check" {
  // OI-J success-only-if-non-null boundary: Binaryen version_130 cannot fold
  // these tests to a constant because null must still return false, but the
  // runtime heap check is redundant when the nullable source heap already
  // matches the non-null target. The safe spelling is eqz(ref.is_null(x)).
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let struct_heap = @lib.HeapType::abs(@lib.AbsHeapType::struct_())
  let maybe_type = @lib.TypeIdx::new(0U)
  let eq_test_type = @lib.TypeIdx::new(1U)
  let struct_test_type = @lib.TypeIdx::new(2U)
  let effect_test_type = @lib.TypeIdx::new(3U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::ref_null(struct_heap)]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::ref_null(eq_heap)], [
              @lib.ValType::i32(),
            ]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::ref_null(struct_heap)], [
              @lib.ValType::i32(),
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
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("m"),
          @lib.Name::from_string("maybe"),
          @lib.ExternType::func(maybe_type),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([eq_test_type, struct_test_type, effect_test_type]),
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
            @lib.Instruction::ref_test(false, struct_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::ref_test(false, struct_heap),
          ]),
        ),
      ]),
    ),
  )
  for func_idx in [1U, 2U, 3U] {
    let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(func_idx))
    assert_false(pretty.contains("ref.test"), msg=pretty)
    assert_true(pretty.contains("i32.eqz"), msg=pretty)
  }
  let effect_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(effect_pretty.contains("call (Func 0)"), msg=effect_pretty)
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
test "optimize-instructions preserves effectful ref.i31 operand for successful ref.test and ref.cast" {
  let effect_type = @lib.TypeIdx::new(0U)
  let test_type = @lib.TypeIdx::new(1U)
  let cast_type = @lib.TypeIdx::new(2U)
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let eq_ref = @lib.ValType::ref_type(@lib.RefType::new(false, eq_heap))
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
          @lib.SubType::comp_type(@lib.CompType::func([], [eq_ref])),
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
            @lib.Instruction::ref_test(false, eq_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::ref_i31(),
            @lib.Instruction::ref_cast(false, eq_heap),
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
  assert_true(test_pretty.contains("I32(1)"), msg=test_pretty)
  assert_false(cast_pretty.contains("ref.cast"), msg=cast_pretty)
  assert_true(cast_pretty.contains("call (Func 0)"), msg=cast_pretty)
  assert_true(cast_pretty.contains("ref.i31"), msg=cast_pretty)
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
test "optimize-instructions preserves effectful prefix for ref.func reference basics" {
  let func_heap = @lib.HeapType::abs(@lib.AbsHeapType::func())
  let non_null_func_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, func_heap),
  )
  let effect_type = @lib.TypeIdx::new(0U)
  let empty_type = @lib.TypeIdx::new(1U)
  let i32_type = @lib.TypeIdx::new(2U)
  let func_ref_type = @lib.TypeIdx::new(3U)
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
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([], [non_null_func_ref])),
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
    .with_func_sec(
      @lib.FuncSec::new([
        empty_type, i32_type, func_ref_type, i32_type, func_ref_type,
      ]),
    )
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(1U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
            @lib.Instruction::ref_test(false, func_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
            @lib.Instruction::ref_cast(false, func_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
            @lib.Instruction::ref_is_null(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
            @lib.Instruction::ref_as_non_null(),
          ]),
        ),
      ]),
    ),
  )
  let test_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let cast_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  let is_null_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  let as_non_null_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(5U))
  assert_false(test_pretty.contains("ref.test"), msg=test_pretty)
  assert_true(test_pretty.contains("call (Func 0)"), msg=test_pretty)
  assert_true(test_pretty.contains("drop"), msg=test_pretty)
  assert_true(test_pretty.contains("I32(1)"), msg=test_pretty)
  assert_false(cast_pretty.contains("ref.cast"), msg=cast_pretty)
  assert_true(cast_pretty.contains("call (Func 0)"), msg=cast_pretty)
  assert_true(cast_pretty.contains("drop"), msg=cast_pretty)
  assert_true(cast_pretty.contains("ref.func"), msg=cast_pretty)
  assert_false(is_null_pretty.contains("ref.is_null"), msg=is_null_pretty)
  assert_true(is_null_pretty.contains("call (Func 0)"), msg=is_null_pretty)
  assert_true(is_null_pretty.contains("drop"), msg=is_null_pretty)
  assert_true(is_null_pretty.contains("I32(0)"), msg=is_null_pretty)
  assert_false(
    as_non_null_pretty.contains("ref.as_non_null"),
    msg=as_non_null_pretty,
  )
  assert_true(
    as_non_null_pretty.contains("call (Func 0)"),
    msg=as_non_null_pretty,
  )
  assert_true(as_non_null_pretty.contains("drop"), msg=as_non_null_pretty)
  assert_true(as_non_null_pretty.contains("ref.func"), msg=as_non_null_pretty)
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
test "optimize-instructions folds known-null ref.test and ref.cast against non-null target" {
  let struct_heap = @lib.HeapType::abs(@lib.AbsHeapType::struct_())
  let struct_ref = @lib.ValType::ref_type(@lib.RefType::new(false, struct_heap))
  let effect_type = @lib.TypeIdx::new(0U)
  let test_type = @lib.TypeIdx::new(1U)
  let cast_type = @lib.TypeIdx::new(2U)
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
    .with_func_sec(
      @lib.FuncSec::new([test_type, cast_type, test_type, cast_type]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::ref_null(struct_heap),
            @lib.Instruction::ref_test(false, struct_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::ref_null(struct_heap),
            @lib.Instruction::ref_cast(false, struct_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::ref_null(struct_heap),
            @lib.Instruction::ref_test(false, struct_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::ref_null(struct_heap),
            @lib.Instruction::ref_cast(false, struct_heap),
          ]),
        ),
      ]),
    ),
  )
  let test_pure = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let cast_pure = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let test_effect = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  let cast_effect = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  assert_false(test_pure.contains("ref.test"), msg=test_pure)
  assert_true(test_pure.contains("I32(0)"), msg=test_pure)
  assert_false(cast_pure.contains("ref.cast"), msg=cast_pure)
  assert_true(cast_pure.contains("unreachable"), msg=cast_pure)
  assert_false(test_effect.contains("ref.test"), msg=test_effect)
  assert_true(test_effect.contains("call (Func 0)"), msg=test_effect)
  assert_true(test_effect.contains("drop"), msg=test_effect)
  assert_true(test_effect.contains("I32(0)"), msg=test_effect)
  assert_false(cast_effect.contains("ref.cast"), msg=cast_effect)
  assert_true(cast_effect.contains("call (Func 0)"), msg=cast_effect)
  assert_true(cast_effect.contains("drop"), msg=cast_effect)
  assert_true(cast_effect.contains("unreachable"), msg=cast_effect)
}

///|
test "optimize-instructions folds nullable i31 local against non-null aggregate ref.test and ref.cast miss" {
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let struct_heap = @lib.HeapType::abs(@lib.AbsHeapType::struct_())
  let nullable_i31_ref = @lib.ValType::ref_null(i31_heap)
  let struct_ref = @lib.ValType::ref_type(@lib.RefType::new(false, struct_heap))
  let i31_i32_type = @lib.TypeIdx::new(0U)
  let i31_struct_type = @lib.TypeIdx::new(1U)
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
            @lib.CompType::func([nullable_i31_ref], [struct_ref]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([i31_i32_type, i31_struct_type]))
    .with_code_sec(
      @lib.CodeSec::new([
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
  let test_struct = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let cast_struct = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(test_struct.contains("ref.test"), msg=test_struct)
  assert_true(test_struct.contains("I32(0)"), msg=test_struct)
  assert_true(cast_struct.contains("unreachable"), msg=cast_struct)
  assert_false(cast_struct.contains("ref.cast"), msg=cast_struct)
}

///|
test "optimize-instructions preserves effectful prefix for nullable i31 local non-null aggregate ref.test and ref.cast miss" {
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let struct_heap = @lib.HeapType::abs(@lib.AbsHeapType::struct_())
  let nullable_i31_ref = @lib.ValType::ref_null(i31_heap)
  let struct_ref = @lib.ValType::ref_type(@lib.RefType::new(false, struct_heap))
  let effect_type = @lib.TypeIdx::new(0U)
  let test_type = @lib.TypeIdx::new(1U)
  let cast_type = @lib.TypeIdx::new(2U)
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
            @lib.CompType::func([nullable_i31_ref], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([nullable_i31_ref], [struct_ref]),
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
    .with_func_sec(@lib.FuncSec::new([test_type, cast_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(false, struct_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(false, struct_heap),
          ]),
        ),
      ]),
    ),
  )
  let test_struct = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let cast_struct = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(test_struct.contains("ref.test"), msg=test_struct)
  assert_true(test_struct.contains("call (Func 0)"), msg=test_struct)
  assert_true(test_struct.contains("drop"), msg=test_struct)
  assert_true(test_struct.contains("I32(0)"), msg=test_struct)
  assert_false(cast_struct.contains("ref.cast"), msg=cast_struct)
  assert_true(cast_struct.contains("call (Func 0)"), msg=cast_struct)
  assert_true(cast_struct.contains("drop"), msg=cast_struct)
  assert_true(cast_struct.contains("unreachable"), msg=cast_struct)
}

///|
test "optimize-instructions preserves effectful prefix for nullable-source non-null-target ref.test and ref.cast miss" {
  let struct_heap = @lib.HeapType::abs(@lib.AbsHeapType::struct_())
  let array_heap = @lib.HeapType::abs(@lib.AbsHeapType::array())
  let nullable_struct_ref = @lib.ValType::ref_null(struct_heap)
  let array_ref = @lib.ValType::ref_type(@lib.RefType::new(false, array_heap))
  let effect_type = @lib.TypeIdx::new(0U)
  let test_type = @lib.TypeIdx::new(1U)
  let cast_type = @lib.TypeIdx::new(2U)
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
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(false, array_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(false, array_heap),
          ]),
        ),
      ]),
    ),
  )
  let test_array = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let cast_array = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(test_array.contains("ref.test"), msg=test_array)
  assert_true(test_array.contains("call (Func 0)"), msg=test_array)
  assert_true(test_array.contains("drop"), msg=test_array)
  assert_true(test_array.contains("I32(0)"), msg=test_array)
  assert_false(cast_array.contains("ref.cast"), msg=cast_array)
  assert_true(cast_array.contains("call (Func 0)"), msg=cast_array)
  assert_true(cast_array.contains("drop"), msg=cast_array)
  assert_true(cast_array.contains("unreachable"), msg=cast_array)
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
test "optimize-instructions preserves effectful prefix for non-null-source nullable-target ref.test and ref.cast" {
  let struct_heap = @lib.HeapType::abs(@lib.AbsHeapType::struct_())
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let array_heap = @lib.HeapType::abs(@lib.AbsHeapType::array())
  let struct_ref = @lib.ValType::ref_type(@lib.RefType::new(false, struct_heap))
  let nullable_eq_ref = @lib.ValType::ref_null(eq_heap)
  let nullable_array_ref = @lib.ValType::ref_null(array_heap)
  let effect_type = @lib.TypeIdx::new(0U)
  let test_type = @lib.TypeIdx::new(1U)
  let cast_success_type = @lib.TypeIdx::new(2U)
  let cast_miss_type = @lib.TypeIdx::new(3U)
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
            @lib.CompType::func([struct_ref], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([struct_ref], [nullable_eq_ref]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([struct_ref], [nullable_array_ref]),
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
    .with_func_sec(
      @lib.FuncSec::new([
        test_type, cast_success_type, test_type, cast_miss_type,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(true, eq_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(true, eq_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(true, array_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(true, array_heap),
          ]),
        ),
      ]),
    ),
  )
  let test_success = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let cast_success = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let test_miss = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  let cast_miss = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  assert_false(test_success.contains("ref.test"), msg=test_success)
  assert_true(test_success.contains("call (Func 0)"), msg=test_success)
  assert_true(test_success.contains("drop"), msg=test_success)
  assert_true(test_success.contains("I32(1)"), msg=test_success)
  assert_false(cast_success.contains("ref.cast"), msg=cast_success)
  assert_true(cast_success.contains("call (Func 0)"), msg=cast_success)
  assert_true(cast_success.contains("drop"), msg=cast_success)
  assert_true(cast_success.contains("local.get"), msg=cast_success)
  assert_false(test_miss.contains("ref.test"), msg=test_miss)
  assert_true(test_miss.contains("call (Func 0)"), msg=test_miss)
  assert_true(test_miss.contains("drop"), msg=test_miss)
  assert_true(test_miss.contains("I32(0)"), msg=test_miss)
  assert_false(cast_miss.contains("ref.cast"), msg=cast_miss)
  assert_true(cast_miss.contains("call (Func 0)"), msg=cast_miss)
  assert_true(cast_miss.contains("drop"), msg=cast_miss)
  assert_true(cast_miss.contains("unreachable"), msg=cast_miss)
}

///|
test "optimize-instructions preserves effectful prefix for non-null-source non-null-target ref.test and ref.cast" {
  let struct_heap = @lib.HeapType::abs(@lib.AbsHeapType::struct_())
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let array_heap = @lib.HeapType::abs(@lib.AbsHeapType::array())
  let struct_ref = @lib.ValType::ref_type(@lib.RefType::new(false, struct_heap))
  let eq_ref = @lib.ValType::ref_type(@lib.RefType::new(false, eq_heap))
  let array_ref = @lib.ValType::ref_type(@lib.RefType::new(false, array_heap))
  let effect_type = @lib.TypeIdx::new(0U)
  let test_type = @lib.TypeIdx::new(1U)
  let cast_success_type = @lib.TypeIdx::new(2U)
  let cast_miss_type = @lib.TypeIdx::new(3U)
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
            @lib.CompType::func([struct_ref], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(@lib.CompType::func([struct_ref], [eq_ref])),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([struct_ref], [array_ref]),
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
    .with_func_sec(
      @lib.FuncSec::new([
        test_type, cast_success_type, test_type, cast_miss_type,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(false, eq_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(false, eq_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(false, array_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(false, array_heap),
          ]),
        ),
      ]),
    ),
  )
  let test_success = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let cast_success = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let test_miss = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  let cast_miss = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  assert_false(test_success.contains("ref.test"), msg=test_success)
  assert_true(test_success.contains("call (Func 0)"), msg=test_success)
  assert_true(test_success.contains("drop"), msg=test_success)
  assert_true(test_success.contains("I32(1)"), msg=test_success)
  assert_false(cast_success.contains("ref.cast"), msg=cast_success)
  assert_true(cast_success.contains("call (Func 0)"), msg=cast_success)
  assert_true(cast_success.contains("drop"), msg=cast_success)
  assert_true(cast_success.contains("local.get"), msg=cast_success)
  assert_false(test_miss.contains("ref.test"), msg=test_miss)
  assert_true(test_miss.contains("call (Func 0)"), msg=test_miss)
  assert_true(test_miss.contains("drop"), msg=test_miss)
  assert_true(test_miss.contains("I32(0)"), msg=test_miss)
  assert_false(cast_miss.contains("ref.cast"), msg=cast_miss)
  assert_true(cast_miss.contains("call (Func 0)"), msg=cast_miss)
  assert_true(cast_miss.contains("drop"), msg=cast_miss)
  assert_true(cast_miss.contains("unreachable"), msg=cast_miss)
}

///|
test "optimize-instructions preserves effectful prefix while folding non-null aggregate ref.is_null" {
  let struct_heap = @lib.HeapType::abs(@lib.AbsHeapType::struct_())
  let array_heap = @lib.HeapType::abs(@lib.AbsHeapType::array())
  let struct_ref = @lib.ValType::ref_type(@lib.RefType::new(false, struct_heap))
  let array_ref = @lib.ValType::ref_type(@lib.RefType::new(false, array_heap))
  let effect_type = @lib.TypeIdx::new(0U)
  let struct_test_type = @lib.TypeIdx::new(1U)
  let array_test_type = @lib.TypeIdx::new(2U)
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
            @lib.CompType::func([struct_ref], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([array_ref], [@lib.ValType::i32()]),
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
    .with_func_sec(@lib.FuncSec::new([struct_test_type, array_test_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_is_null(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_is_null(),
          ]),
        ),
      ]),
    ),
  )
  let struct_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let array_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  for pretty in [struct_pretty, array_pretty] {
    assert_false(pretty.contains("ref.is_null"), msg=pretty)
    assert_true(pretty.contains("call (Func 0)"), msg=pretty)
    assert_true(pretty.contains("drop"), msg=pretty)
    assert_true(pretty.contains("I32(0)"), msg=pretty)
  }
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
test "optimize-instructions preserves effectful prefix for nullable-source nullable-target ref.test and ref.cast" {
  let struct_heap = @lib.HeapType::abs(@lib.AbsHeapType::struct_())
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let nullable_struct_ref = @lib.ValType::ref_null(struct_heap)
  let nullable_eq_ref = @lib.ValType::ref_null(eq_heap)
  let effect_type = @lib.TypeIdx::new(0U)
  let test_type = @lib.TypeIdx::new(1U)
  let cast_type = @lib.TypeIdx::new(2U)
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
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(true, eq_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(true, eq_heap),
          ]),
        ),
      ]),
    ),
  )
  let test_eq = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let cast_eq = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(test_eq.contains("ref.test"), msg=test_eq)
  assert_true(test_eq.contains("call (Func 0)"), msg=test_eq)
  assert_true(test_eq.contains("drop"), msg=test_eq)
  assert_true(test_eq.contains("I32(1)"), msg=test_eq)
  assert_false(cast_eq.contains("ref.cast"), msg=cast_eq)
  assert_true(cast_eq.contains("call (Func 0)"), msg=cast_eq)
  assert_true(cast_eq.contains("drop"), msg=cast_eq)
  assert_true(cast_eq.contains("local.get"), msg=cast_eq)
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
test "optimize-instructions preserves effectful prefix for nullable-source nullable-target i31 ref.test and ref.cast" {
  let i31_heap = @lib.HeapType::abs(@lib.AbsHeapType::i31())
  let eq_heap = @lib.HeapType::abs(@lib.AbsHeapType::eq())
  let nullable_i31_ref = @lib.ValType::ref_null(i31_heap)
  let nullable_eq_ref = @lib.ValType::ref_null(eq_heap)
  let effect_type = @lib.TypeIdx::new(0U)
  let test_type = @lib.TypeIdx::new(1U)
  let cast_type = @lib.TypeIdx::new(2U)
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
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(true, eq_heap),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(true, eq_heap),
          ]),
        ),
      ]),
    ),
  )
  let test_eq = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let cast_eq = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(test_eq.contains("ref.test"), msg=test_eq)
  assert_true(test_eq.contains("call (Func 0)"), msg=test_eq)
  assert_true(test_eq.contains("drop"), msg=test_eq)
  assert_true(test_eq.contains("I32(1)"), msg=test_eq)
  assert_false(cast_eq.contains("ref.cast"), msg=cast_eq)
  assert_true(cast_eq.contains("call (Func 0)"), msg=cast_eq)
  assert_true(cast_eq.contains("drop"), msg=cast_eq)
  assert_true(cast_eq.contains("local.get"), msg=cast_eq)
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
test "optimize-instructions intentionally keeps multi-result argument select call_ref boundary" {
  // Boundary-only OI-H classification: Binaryen `version_130`
  // localizes a multi-result argument producer through tuple scratch plus scalar
  // temps before lowering select-of-`ref.func` call_ref / return_call_ref to a
  // direct-call if (`.tmp/oi-h-multivalue-arg-select-probe.wat` and
  // `.tmp/oi-h-multivalue-arg-select-return-probe.wat`). Starshine's current
  // call_ref localizer only proves scalar single-result call arguments, so this
  // public fixture keeps call_ref forms instead of hiding the broader
  // multivalue localization gap as parity.
  let target_type_idx = @lib.TypeIdx::new(0U)
  let pair_type_idx = @lib.TypeIdx::new(1U)
  let caller_type_idx = @lib.TypeIdx::new(2U)
  let target_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
        @lib.ValType::i32(),
      ]),
    ),
  )
  let pair_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([], [@lib.ValType::i32(), @lib.ValType::i32()]),
    ),
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
    .with_type_sec(@lib.TypeSec::new([target_type, pair_type, caller_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        target_type_idx, target_type_idx, pair_type_idx, caller_type_idx, caller_type_idx,
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
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(1U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(2)),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
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
            @lib.Instruction::call(@lib.FuncIdx::new(2U)),
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
  let caller = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(caller.contains("call_ref"), msg=caller)
  assert_true(caller.contains("select"), msg=caller)
  assert_true(caller.contains("ref.func"), msg=caller)
  assert_true(caller.contains("call (Func 2)"), msg=caller)
  assert_false(caller.contains("call (Func 0)"), msg=caller)
  assert_false(caller.contains("call (Func 1)"), msg=caller)
  let tail = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  assert_true(tail.contains("return_call_ref"), msg=tail)
  assert_true(tail.contains("select"), msg=tail)
  assert_true(tail.contains("ref.func"), msg=tail)
  assert_true(tail.contains("call (Func 2)"), msg=tail)
  assert_false(tail.contains("return_call (Func 0)"), msg=tail)
  assert_false(tail.contains("return_call (Func 1)"), msg=tail)
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
test "optimize-instructions localizes argument fallthrough call_ref targets" {
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
  assert_true(caller.contains("local.set"), msg=caller)
  assert_true(caller.contains("call (Func 0)"), msg=caller)
  assert_true(caller.contains("call (Func 1)"), msg=caller)
  assert_true(caller.contains("call (Func 2)"), msg=caller)
  assert_false(caller.contains("call_ref"), msg=caller)
  assert_true(caller.contains("ref.func"), msg=caller)
  assert_true(tail.contains("local.set"), msg=tail)
  assert_true(tail.contains("return_call (Func 0)"), msg=tail)
  assert_true(tail.contains("call (Func 1)"), msg=tail)
  assert_true(tail.contains("call (Func 2)"), msg=tail)
  assert_false(tail.contains("return_call_ref"), msg=tail)
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
test "optimize-instructions directizes call-indexed table.get call_ref targets" {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let index_type_idx = @lib.TypeIdx::new(1U)
  let callee_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let index_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
  )
  let typed_func_ref = @lib.RefType::new(
    true,
    @lib.HeapType::new(callee_type_idx),
  )
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([callee_type, index_type]))
    .with_import_sec(
      @lib.ImportSec::new([
        @lib.Import::new(
          @lib.Name::from_string("m"),
          @lib.Name::from_string("index"),
          @lib.ExternType::func(index_type_idx),
        ),
      ]),
    )
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
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::table_get(@lib.TableIdx::new(0U)),
            @lib.Instruction::call_ref(callee_type_idx),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::table_get(@lib.TableIdx::new(0U)),
            @lib.Instruction::return_call_ref(callee_type_idx),
          ]),
        ),
      ]),
    ),
  )
  let caller = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let tail = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(caller.contains("call_indirect (Type 0) (Table 0)"), msg=caller)
  assert_true(caller.contains("call (Func 0)"), msg=caller)
  assert_false(caller.contains("call_ref"), msg=caller)
  assert_false(caller.contains("table.get"), msg=caller)
  assert_true(
    tail.contains("return_call_indirect (Type 0) (Table 0)"),
    msg=tail,
  )
  assert_true(tail.contains("call (Func 0)"), msg=tail)
  assert_false(tail.contains("return_call_ref"), msg=tail)
  assert_false(tail.contains("table.get"), msg=tail)
}

///|
test "optimize-instructions intentionally rejects unsupported GC atomic RMW surface" {
  // OI-L boundary: Binaryen version_130 optimizes struct.atomic.rmw.add(0),
  // struct.atomic.rmw.and(-1), and struct.atomic.rmw.cmpxchg(expected ==
  // replacement) to struct.get-like reads for the probed acqrel/acqrel forms.
  // Starshine currently represents only struct.atomic.get* in its aggregate
  // atomic text/core surface, so RMW/cmpxchg must stay an explicit unsupported
  // boundary instead of being hidden as pass parity.
  let rmw_src =
    #|(module
    #|  (type $S (struct (field (mut i32))))
    #|  (func (param $s (ref $S)) (result i32)
    #|    (struct.atomic.rmw.add acqrel acqrel $S 0
    #|      (local.get $s)
    #|      (i32.const 0))))
    #|
  match @wast.wast_to_binary_module(rmw_src) {
    Ok(_) => fail("expected unsupported struct.atomic.rmw surface to reject")
    Err(_) => ()
  }

  let cmpxchg_src =
    #|(module
    #|  (type $S (struct (field (mut i32))))
    #|  (func (param $s (ref $S)) (result i32)
    #|    (struct.atomic.rmw.cmpxchg acqrel acqrel $S 0
    #|      (local.get $s)
    #|      (i32.const 7)
    #|      (i32.const 7))))
    #|
  match @wast.wast_to_binary_module(cmpxchg_src) {
    Ok(_) =>
      fail("expected unsupported struct.atomic.rmw.cmpxchg surface to reject")
    Err(_) => ()
  }
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
test "optimize-instructions expands stack-carried effectful tiny memory.copy" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (import "env" "dst" (func $dst (result i32)))
        #|  (import "env" "src" (func $src (result i32)))
        #|  (memory 1)
        #|  (func
        #|    call $dst
        #|    call $src
        #|    i32.const 1
        #|    memory.copy
        #|    call $dst
        #|    call $src
        #|    i32.const 8
        #|    memory.copy))
        #|,
      ),
      ["optimize-instructions"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected effectful memory.copy optimize success, got \{err}")
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[optimize-instructions]:skip-raw reason=stack-carried-effect-optimize-instructions-noop",
      )
    }),
    msg=trace.to_string(),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  // Binaryen version_130 lowers these size-1/8 copies to load/store despite the
  // call operands; the store address child is emitted before the nested load,
  // preserving the original dst-call then src-call evaluation order.
  assert_false(pretty.contains("memory.copy"), msg=pretty)
  optimize_instructions_assert_strings_in_order(pretty, [
    "call (Func 0)", "call (Func 1)", "i32.load8u", "i32.store8", "call (Func 0)",
    "call (Func 1)", "i64.load", "i64.store",
  ])
}

///|
test "optimize-instructions expands stack-carried effectful v128 memory.copy" {
  // Coverage/status OI-G classification: Binaryen `version_130`
  // `--optimize-instructions` lowers the exact flat call-backed size-16
  // `memory.copy` shape to one `v128.load` plus one `v128.store`
  // (`.tmp/oi-g-stack-call-memory-copy-16-probe.wat`). Starshine's raw-gate
  // escape already admits this size-16 shape; this test locks the v128 lane and
  // call-order evidence without claiming broader stack-carried localization.
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (import "env" "dst" (func $dst (result i32)))
        #|  (import "env" "src" (func $src (result i32)))
        #|  (memory 1)
        #|  (func
        #|    call $dst
        #|    call $src
        #|    i32.const 16
        #|    memory.copy))
        #|,
      ),
      ["optimize-instructions"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected effectful v128 memory.copy optimize success, got \{err}")
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[optimize-instructions]:skip-raw reason=stack-carried-effect-optimize-instructions-noop",
      )
    }),
    msg="expected size-16 stack memory.copy raw escape, trace=\{trace}",
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(pretty.contains("memory.copy"), msg=pretty)
  optimize_instructions_assert_strings_in_order(pretty, [
    "call (Func 0)", "call (Func 1)", "v128.load", "v128.store",
  ])
}

///|
test "optimize-instructions expands stack-carried parameterized tiny memory.copy" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func $dst (param i32) (result i32) local.get 0)
        #|  (func $src (param i32) (result i32) local.get 0)
        #|  (func (param $d i32) (param $s i32)
        #|    local.get $d
        #|    call $dst
        #|    local.get $s
        #|    call $src
        #|    i32.const 1
        #|    memory.copy
        #|    local.get $d
        #|    call $dst
        #|    local.get $s
        #|    call $src
        #|    i32.const 8
        #|    memory.copy))
        #|,
      ),
      ["optimize-instructions"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected parameterized memory.copy optimize success, got \{err}")
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[optimize-instructions]:skip-raw reason=stack-carried-effect-optimize-instructions-noop",
      )
    }),
    msg="expected parameterized stack memory.copy raw escape, trace=\{trace}",
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  // Binaryen version_130 lowers the same parameterized-call shape
  // (`.tmp/oi-g-parameterized-memory-copy-probe.wat`), so this is a narrow raw
  // gate escape rather than a broad stack-carried/localizing claim.
  assert_false(pretty.contains("memory.copy"), msg=pretty)
  optimize_instructions_assert_strings_in_order(pretty, [
    "(local.get (Local 0))", "call (Func 0)", "(local.get (Local 1))", "call (Func 1)",
    "i32.load8u", "i32.store8", "(local.get (Local 0))", "call (Func 0)", "(local.get (Local 1))",
    "call (Func 1)", "i64.load", "i64.store",
  ])
}

///|
test "optimize-instructions expands stack-carried mixed parameterized tiny memory.copy" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func $dst1 (param i32) (result i32) local.get 0)
        #|  (func $src0 (result i32) i32.const 16)
        #|  (func $dst0 (result i32) i32.const 32)
        #|  (func $src1 (param i32) (result i32) local.get 0)
        #|  (func (param $d i32) (param $s i32)
        #|    local.get $d
        #|    call $dst1
        #|    call $src0
        #|    i32.const 1
        #|    memory.copy
        #|    call $dst0
        #|    local.get $s
        #|    call $src1
        #|    i32.const 8
        #|    memory.copy))
        #|,
      ),
      ["optimize-instructions"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected mixed parameterized memory.copy optimize success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[optimize-instructions]:skip-raw reason=stack-carried-effect-optimize-instructions-noop",
      )
    }),
    msg="expected mixed parameterized stack memory.copy raw escape, trace=\{trace}",
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  // Binaryen version_130 lowers the mixed one-arg/no-arg direct-call address
  // shape (`.tmp/oi-g-mixed-parameterized-memory-copy-probe.wat`). This remains
  // a narrow raw-gate escape for pure local/constant unary-call arguments, not a
  // broad stack-carried/localizing claim.
  assert_false(pretty.contains("memory.copy"), msg=pretty)
  optimize_instructions_assert_strings_in_order(pretty, [
    "(local.get (Local 0))", "call (Func 0)", "call (Func 1)", "i32.load8u", "i32.store8",
    "call (Func 2)", "(local.get (Local 1))", "call (Func 3)", "i64.load", "i64.store",
  ])
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
        #|    memory.copy
        #|    local.get $dst
        #|    local.get $src
        #|    i32.const 16
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
    "v128.load", "v128.store",
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
        #|    i32.const 3
        #|    memory.copy
        #|    local.get $dst
        #|    local.get $src
        #|    i32.const 32
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
  // zero-size memory.copy is kept; Binaryen also keeps size-3 copy spelling
  // (`.tmp/oi-g-memory-copy-size3-boundary-probe.wat`) rather than widening to
  // multiple narrow stores, and larger/nonconstant copies are kept too.
  @debug.assert_eq(
    optimize_instructions_test_count_substring(pretty, "memory.copy"),
    4,
    msg=pretty,
  )
  assert_false(pretty.contains("i32.load8u"), msg=pretty)
  assert_false(pretty.contains("i32.store8"), msg=pretty)
  assert_false(pretty.contains("i32.load16u"), msg=pretty)
  assert_false(pretty.contains("i32.store16"), msg=pretty)
  assert_false(pretty.contains("i64.load"), msg=pretty)
  assert_false(pretty.contains("i64.store"), msg=pretty)
  assert_false(pretty.contains("v128.load"), msg=pretty)
  assert_false(pretty.contains("v128.store"), msg=pretty)
}

///|
test "optimize-instructions keeps zero-size bulk-memory with effectful operands" {
  // Boundary-only OI-G classification: Binaryen `version_130`
  // `--optimize-instructions` keeps zero-size memory.copy/fill even when the
  // destination, source, and fill value operands are calls
  // (`.tmp/oi-g-zero-bulk-effect-probe.wat`). Starshine likewise keeps the
  // original bulk-memory operations rather than dropping evaluated operands.
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func $dst (result i32) (i32.const 0))
        #|  (func $src (result i32) (i32.const 4))
        #|  (func $val (result i32) (i32.const 255))
        #|  (func
        #|    call $dst
        #|    call $src
        #|    i32.const 0
        #|    memory.copy
        #|    call $dst
        #|    call $val
        #|    i32.const 0
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected zero-size bulk-memory boundary success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(pretty.contains("memory.copy"), msg=pretty)
  assert_true(pretty.contains("memory.fill"), msg=pretty)
  optimize_instructions_assert_strings_in_order(pretty, [
    "call (Func 0)", "call (Func 1)", "memory.copy", "call (Func 0)", "call (Func 2)",
    "memory.fill",
  ])
  assert_false(pretty.contains("i32.load8u"), msg=pretty)
  assert_false(pretty.contains("i32.store8"), msg=pretty)
}

///|
test "optimize-instructions keeps nonconstant bulk-memory with effectful size" {
  // Boundary-only OI-G classification: Binaryen `version_130`
  // `--optimize-instructions` keeps memory.copy/fill with call-backed dynamic
  // sizes (`.tmp/oi-g-nonconstant-bulk-effects-probe.wat`). Starshine likewise
  // keeps the bulk operations and operand order instead of pretending the size
  // is one of the exact tiny constants it can lower safely.
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func $dst (result i32) (i32.const 0))
        #|  (func $src (result i32) (i32.const 4))
        #|  (func $size (result i32) (i32.const 3))
        #|  (func $val (result i32) (i32.const 255))
        #|  (func
        #|    call $dst
        #|    call $src
        #|    call $size
        #|    memory.copy
        #|    call $dst
        #|    call $val
        #|    call $size
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected nonconstant bulk-memory boundary success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  assert_true(pretty.contains("memory.copy"), msg=pretty)
  assert_true(pretty.contains("memory.fill"), msg=pretty)
  optimize_instructions_assert_strings_in_order(pretty, [
    "call (Func 0)", "call (Func 1)", "call (Func 2)", "memory.copy", "call (Func 0)",
    "call (Func 3)", "call (Func 2)", "memory.fill",
  ])
  assert_false(pretty.contains("i32.load8u"), msg=pretty)
  assert_false(pretty.contains("i32.store8"), msg=pretty)
  assert_false(pretty.contains("i32.load16u"), msg=pretty)
  assert_false(pretty.contains("i32.store16"), msg=pretty)
  assert_false(pretty.contains("i64.load"), msg=pretty)
  assert_false(pretty.contains("i64.store"), msg=pretty)
}

///|
test "optimize-instructions keeps local dynamic-size bulk-memory" {
  // Boundary-only OI-G classification: Binaryen `version_130`
  // `--optimize-instructions` keeps `memory.copy` and `memory.fill` when the
  // size is a nonconstant local (`.tmp/oi-g-local-dynamic-bulk-probe.wat`).
  // Starshine likewise keeps the dynamic bulk-memory operations instead of
  // guessing one of the exact constant tiny lowerings.
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $dst i32) (param $src i32) (param $size i32) (param $val i32)
        #|    local.get $dst
        #|    local.get $src
        #|    local.get $size
        #|    memory.copy
        #|    local.get $dst
        #|    local.get $val
        #|    local.get $size
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected local dynamic bulk-memory boundary success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.copy"), msg=pretty)
  assert_true(pretty.contains("memory.fill"), msg=pretty)
  optimize_instructions_assert_strings_in_order(pretty, [
    "local.get (Local 0)", "local.get (Local 1)", "local.get (Local 2)", "memory.copy",
    "local.get (Local 0)", "local.get (Local 3)", "local.get (Local 2)", "memory.fill",
  ])
  assert_false(pretty.contains("i32.load8u"), msg=pretty)
  assert_false(pretty.contains("i32.store8"), msg=pretty)
  assert_false(pretty.contains("i32.load16u"), msg=pretty)
  assert_false(pretty.contains("i32.store16"), msg=pretty)
  assert_false(pretty.contains("i64.load"), msg=pretty)
  assert_false(pretty.contains("i64.store"), msg=pretty)
  assert_false(pretty.contains("v128.load"), msg=pretty)
  assert_false(pretty.contains("v128.store"), msg=pretty)
}

///|
test "optimize-instructions keeps global dynamic-size bulk-memory" {
  // Boundary-only OI-G classification: Binaryen `version_130`
  // `--optimize-instructions` keeps `memory.copy` and `memory.fill` when the
  // size is a nonconstant global (`.tmp/oi-g-global-dynamic-bulk-probe.wat`).
  // Starshine likewise keeps the dynamic bulk-memory operations instead of
  // treating global-backed sizes as exact constant tiny lowerings.
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (global $n (mut i32) (i32.const 9))
        #|  (func (param $dst i32) (param $src i32) (param $val i32)
        #|    local.get $dst
        #|    local.get $src
        #|    global.get $n
        #|    memory.copy
        #|    local.get $dst
        #|    local.get $val
        #|    global.get $n
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected global dynamic bulk-memory boundary success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.copy"), msg=pretty)
  assert_true(pretty.contains("memory.fill"), msg=pretty)
  optimize_instructions_assert_strings_in_order(pretty, [
    "local.get (Local 0)", "local.get (Local 1)", "global.get (Global 0)", "memory.copy",
    "local.get (Local 0)", "local.get (Local 2)", "global.get (Global 0)", "memory.fill",
  ])
  assert_false(pretty.contains("i32.load8u"), msg=pretty)
  assert_false(pretty.contains("i32.store8"), msg=pretty)
  assert_false(pretty.contains("i32.load16u"), msg=pretty)
  assert_false(pretty.contains("i32.store16"), msg=pretty)
  assert_false(pretty.contains("i64.load"), msg=pretty)
  assert_false(pretty.contains("i64.store"), msg=pretty)
  assert_false(pretty.contains("v128.load"), msg=pretty)
  assert_false(pretty.contains("v128.store"), msg=pretty)
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
test "optimize-instructions expands byte memory.fill with local and call values" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func $get (result i32) (i32.const 511))
        #|  (func (param $dst i32) (param $value i32)
        #|    local.get $dst
        #|    local.get $value
        #|    i32.const 1
        #|    memory.fill
        #|    local.get $dst
        #|    call $get
        #|    i32.const 1
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected byte memory.fill value optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("memory.fill"), msg=pretty)
  @debug.assert_eq(
    optimize_instructions_test_count_substring(pretty, "i32.store8"),
    2,
    msg=pretty,
  )
  optimize_instructions_assert_strings_in_order(pretty, [
    "(local.get (Local 0))", "(local.get (Local 1))", "i32.store8", "(local.get (Local 0))",
    "call (Func 0)", "i32.store8",
  ])
}

///|
test "optimize-instructions expands stack-carried parameterized byte memory.fill" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func $dst1 (param i32) (result i32) local.get 0)
        #|  (func $val1 (param i32) (result i32) local.get 0)
        #|  (func $dst0 (result i32) i32.const 32)
        #|  (func (param $d i32) (param $v i32)
        #|    local.get $d
        #|    call $dst1
        #|    local.get $v
        #|    call $val1
        #|    i32.const 1
        #|    memory.fill
        #|    call $dst0
        #|    local.get $v
        #|    call $val1
        #|    i32.const 1
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected parameterized byte memory.fill optimize success, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[optimize-instructions]:skip-raw reason=stack-carried-effect-optimize-instructions-noop",
      )
    }),
    msg="expected parameterized byte memory.fill raw escape, trace=\{trace}",
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  // Binaryen version_130 lowers these parameterized byte fills to store8
  // (`.tmp/oi-g-parameterized-byte-fill-probe.wat`). Wider call-backed fills
  // remain source-backed keep-spelling boundaries.
  assert_false(pretty.contains("memory.fill"), msg=pretty)
  @debug.assert_eq(
    optimize_instructions_test_count_substring(pretty, "i32.store8"),
    2,
    msg=pretty,
  )
  optimize_instructions_assert_strings_in_order(pretty, [
    "(local.get (Local 0))", "call (Func 0)", "(local.get (Local 1))", "call (Func 1)",
    "i32.store8", "call (Func 2)", "(local.get (Local 1))", "call (Func 1)", "i32.store8",
  ])
}

///|
test "optimize-instructions expands stack-carried multi-parameter bulk-memory calls" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func $dst2 (param i32 i32) (result i32)
        #|    local.get 0
        #|    local.get 1
        #|    i32.add)
        #|  (func $src2 (param i32 i32) (result i32)
        #|    local.get 0
        #|    local.get 1
        #|    i32.add)
        #|  (func $value2 (param i32 i32) (result i32)
        #|    local.get 0
        #|    local.get 1
        #|    i32.add)
        #|  (func (param $a i32) (param $b i32) (param $v i32)
        #|    local.get $a
        #|    local.get $b
        #|    call $dst2
        #|    local.get $b
        #|    local.get $a
        #|    call $src2
        #|    i32.const 1
        #|    memory.copy
        #|    local.get $a
        #|    local.get $b
        #|    call $dst2
        #|    local.get $v
        #|    i32.const 1
        #|    memory.fill
        #|    local.get $a
        #|    local.get $b
        #|    call $dst2
        #|    local.get $a
        #|    local.get $v
        #|    call $value2
        #|    i32.const 1
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected multi-parameter bulk-memory optimize success, got \{err}")
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[optimize-instructions]:skip-raw reason=stack-carried-effect-optimize-instructions-noop",
      )
    }),
    msg="expected multi-parameter bulk-memory raw escape, trace=\{trace}",
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  // Binaryen version_130 lowers these pure-argument multi-parameter call
  // operands (`.tmp/oi-g-multiparam-bulk-memory-boundary-probe.wat`).
  // Broader non-pure/control-bearing call arguments remain open.
  assert_false(pretty.contains("memory.copy"), msg=pretty)
  assert_false(pretty.contains("memory.fill"), msg=pretty)
  assert_true(pretty.contains("i32.load8u"), msg=pretty)
  @debug.assert_eq(
    optimize_instructions_test_count_substring(pretty, "i32.store8"),
    3,
  )
}

///|
test "optimize-instructions expands stack-carried global bulk-memory calls" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (global $d (mut i32) (i32.const 0))
        #|  (global $s (mut i32) (i32.const 8))
        #|  (global $v (mut i32) (i32.const 255))
        #|  (func $dst (param i32) (result i32)
        #|    local.get 0)
        #|  (func $src (param i32) (result i32)
        #|    local.get 0)
        #|  (func $val (param i32) (result i32)
        #|    local.get 0)
        #|  (func
        #|    global.get $d
        #|    call $dst
        #|    global.get $s
        #|    call $src
        #|    i32.const 1
        #|    memory.copy
        #|    global.get $d
        #|    global.get $v
        #|    call $val
        #|    i32.const 1
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected global bulk-memory optimize success, got \{err}")
  }
  assert_false(
    trace.any(fn(line) {
      line.contains(
        "pass[optimize-instructions]:skip-raw reason=stack-carried-effect-optimize-instructions-noop",
      )
    }),
    msg="expected global bulk-memory raw escape, trace=\{trace}",
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  // Binaryen version_130 lowers the same mutable-global operand shape
  // (`.tmp/oi-g-global-bulk-memory-probe.wat`). This raw-gate escape is limited
  // to tiny bulk-memory operands and does not generalize global.get to the
  // commutative stack-call binop gate, where call/global reordering would be
  // unsafe if a call mutates the global.
  assert_false(pretty.contains("memory.copy"), msg=pretty)
  assert_false(pretty.contains("memory.fill"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("i32.load8u"), msg=pretty)
  @debug.assert_eq(
    optimize_instructions_test_count_substring(pretty, "i32.store8"),
    2,
    msg=pretty,
  )
  optimize_instructions_assert_strings_in_order(pretty, [
    "global.get", "call (Func 0)", "global.get", "call (Func 1)", "i32.load8u", "i32.store8",
    "global.get", "global.get", "call (Func 2)", "i32.store8",
  ])
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
test "optimize-instructions expands constant sixteen-byte memory.fill to v128.store" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $dst i32)
        #|    local.get $dst
        #|    i32.const 0
        #|    i32.const 16
        #|    memory.fill)
        #|  (func (param $dst i32)
        #|    local.get $dst
        #|    i32.const 171
        #|    i32.const 16
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected sixteen-byte memory.fill optimize success, got \{err}")
  }
  let zero = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(zero.contains("memory.fill"), msg=zero)
  assert_true(zero.contains("v128.const"), msg=zero)
  assert_true(zero.contains("v128.store"), msg=zero)
  let nonzero = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(nonzero.contains("memory.fill"), msg=nonzero)
  assert_true(nonzero.contains("v128.const"), msg=nonzero)
  assert_true(nonzero.contains("v128.store"), msg=nonzero)
  assert_true(nonzero.contains("abab"), msg=nonzero)
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
test "optimize-instructions keeps size-3 memory.fill outside exact lowering boundary" {
  // Boundary-only OI-G classification: Binaryen `version_130`
  // `--optimize-instructions` keeps non-power-of-two size-3 `memory.fill`
  // (`.tmp/oi-g-memory-fill-size3-boundary-probe.wat`). Starshine likewise
  // avoids inventing a partial-store sequence beyond the exact 1/2/4/8/16
  // lowering set.
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $dst i32) (param $value i32)
        #|    local.get $dst
        #|    local.get $value
        #|    i32.const 3
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected size-3 memory.fill boundary success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.fill"), msg=pretty)
  assert_false(pretty.contains("i32.store8"), msg=pretty)
  assert_false(pretty.contains("i32.store16"), msg=pretty)
  assert_false(pretty.contains("i32.store"), msg=pretty)
  assert_false(pretty.contains("i64.store"), msg=pretty)
  assert_false(pretty.contains("v128.store"), msg=pretty)
}

///|
test "optimize-instructions keeps size-5 bulk-memory outside exact lowering boundary" {
  // Boundary-only OI-G classification: Binaryen `version_130`
  // `--optimize-instructions` keeps size-5 `memory.copy` and `memory.fill`
  // (`.tmp/oi-g-memory-copy-size5-probe.wat`) rather than synthesizing mixed
  // 4+1 load/store sequences. Starshine likewise keeps the bulk-memory spelling
  // outside the exact 1/2/4/8/16 memory.copy and 1/2/4/8/16 fill lanes.
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $dst i32) (param $src i32) (param $value i32)
        #|    local.get $dst
        #|    local.get $src
        #|    i32.const 5
        #|    memory.copy
        #|    local.get $dst
        #|    local.get $value
        #|    i32.const 5
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected size-5 bulk-memory boundary success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.copy"), msg=pretty)
  assert_true(pretty.contains("memory.fill"), msg=pretty)
  assert_false(pretty.contains("i32.load8u"), msg=pretty)
  assert_false(pretty.contains("i32.store8"), msg=pretty)
  assert_false(pretty.contains("i32.load"), msg=pretty)
  assert_false(pretty.contains("i32.store"), msg=pretty)
  assert_false(pretty.contains("i64.load"), msg=pretty)
  assert_false(pretty.contains("i64.store"), msg=pretty)
  assert_false(pretty.contains("v128.load"), msg=pretty)
  assert_false(pretty.contains("v128.store"), msg=pretty)
}

///|
test "optimize-instructions keeps size-7 bulk-memory outside exact lowering boundary" {
  // Boundary-only OI-G classification: Binaryen `version_130`
  // `--optimize-instructions` keeps size-7 `memory.copy` and `memory.fill`
  // (`.tmp/oi-g-memory-copy-size7-probe.wat`) rather than synthesizing mixed
  // 4+2+1 load/store sequences. Starshine likewise keeps the bulk-memory
  // spelling outside the exact 1/2/4/8/16 memory.copy and 1/2/4/8/16 fill lanes.
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $dst i32) (param $src i32) (param $value i32)
        #|    local.get $dst
        #|    local.get $src
        #|    i32.const 7
        #|    memory.copy
        #|    local.get $dst
        #|    local.get $value
        #|    i32.const 7
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected size-7 bulk-memory boundary success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("memory.copy"), msg=pretty)
  assert_true(pretty.contains("memory.fill"), msg=pretty)
  assert_false(pretty.contains("i32.load8u"), msg=pretty)
  assert_false(pretty.contains("i32.store8"), msg=pretty)
  assert_false(pretty.contains("i32.load16u"), msg=pretty)
  assert_false(pretty.contains("i32.store16"), msg=pretty)
  assert_false(pretty.contains("i32.load"), msg=pretty)
  assert_false(pretty.contains("i32.store"), msg=pretty)
  assert_false(pretty.contains("i64.load"), msg=pretty)
  assert_false(pretty.contains("i64.store"), msg=pretty)
  assert_false(pretty.contains("v128.load"), msg=pretty)
  assert_false(pretty.contains("v128.store"), msg=pretty)
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
test "optimize-instructions intentionally keeps non-local wider memory.fill values" {
  // Binaryen version_130 keeps call-backed and computed non-local fill values
  // here, including call-backed and local.get-backed size-16 SIMD-width fills
  // in `.tmp/oi-g-stack-call-memory-fill-16-probe.wat` and
  // `.tmp/oi-g-local-v128-memory-fill-boundary-probe.wat`. The covered
  // positive lowering remains limited to constants and direct local.get values
  // below SIMD width, so this boundary is not counted as a missing OI-G
  // materialization gap.
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
        #|    memory.fill)
        #|  (func (param $dst i32) (param $value i32)
        #|    local.get $dst
        #|    local.get $value
        #|    i32.const 1
        #|    i32.add
        #|    i32.const 4
        #|    memory.fill)
        #|  (func (param $dst i32)
        #|    local.get $dst
        #|    call $get
        #|    i32.const 16
        #|    memory.fill)
        #|  (func (param $dst i32) (param $value i32)
        #|    local.get $dst
        #|    local.get $value
        #|    i32.const 16
        #|    memory.fill))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected non-local memory.fill boundary success, got \{err}")
  }
  let effectful = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(effectful.contains("memory.fill"), msg=effectful)
  assert_true(effectful.contains("call (Func 0)"), msg=effectful)
  let computed = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(computed.contains("memory.fill"), msg=computed)
  assert_true(computed.contains("i32.add"), msg=computed)
  let simd_width = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(simd_width.contains("memory.fill"), msg=simd_width)
  assert_true(simd_width.contains("call (Func 0)"), msg=simd_width)
  assert_false(simd_width.contains("v128.store"), msg=simd_width)
  let local_simd_width = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  assert_true(local_simd_width.contains("memory.fill"), msg=local_simd_width)
  assert_true(
    local_simd_width.contains("local.get (Local 1)"),
    msg=local_simd_width,
  )
  assert_false(local_simd_width.contains("v128.store"), msg=local_simd_width)
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
test "optimize-instructions widens narrow stores of i32.wrap_i64 to matching i64 stores" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $ptr i32) (param $x i64)
        #|    local.get $ptr
        #|    local.get $x
        #|    i32.wrap_i64
        #|    i32.store8
        #|    local.get $ptr
        #|    local.get $x
        #|    i32.wrap_i64
        #|    i32.store16
        #|    local.get $ptr
        #|    local.get $x
        #|    i32.wrap_i64
        #|    i32.store))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected wrap-store optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  // Storing the low N bits of (i32.wrap_i64 x) is equivalent to storing the low
  // N bits of x directly via the matching i64 narrow store, so the wrap is
  // dropped and the store widens: i32.store8/16 -> i64.store8/16 and the full
  // i32.store -> i64.store32.
  assert_false(pretty.contains("wrap_i64"), msg=pretty)
  optimize_instructions_assert_strings_in_order(pretty, [
    "(local.get (Local 0))", "(local.get (Local 1))", "i64.store8", "(local.get (Local 0))",
    "(local.get (Local 1))", "i64.store16", "(local.get (Local 0))", "(local.get (Local 1))",
    "i64.store32",
  ])
}

///|
test "optimize-instructions preserves memargs when widening i32.wrap_i64 stores" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $ptr i32) (param $x i64)
        #|    local.get $ptr
        #|    local.get $x
        #|    i32.wrap_i64
        #|    i32.store8 offset=4 align=1
        #|    local.get $ptr
        #|    local.get $x
        #|    i32.wrap_i64
        #|    i32.store16 offset=8 align=1
        #|    local.get $ptr
        #|    local.get $x
        #|    i32.wrap_i64
        #|    i32.store offset=12 align=1))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected wrap-store memarg optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("wrap_i64"), msg=pretty)
  optimize_instructions_assert_strings_in_order(pretty, [
    "i64.store8 align=U32(0) offset=U64(4)", "i64.store16 align=U32(0) offset=U64(8)",
    "i64.store32 align=U32(0) offset=U64(12)",
  ])
}

///|
test "optimize-instructions intentionally keeps multi-use i32.wrap_i64 store boundary" {
  // Boundary-only OI-G classification: Binaryen `version_130`
  // `--optimize-instructions` keeps a local-carried/shared `i32.wrap_i64`
  // value before a narrow store (`.tmp/oi-g-wrap-store-multiuse-probe.wat`).
  // Starshine's widening helper is deliberately one-use-only, so this public
  // fixture prevents the covered direct-store rewrite from being reported as
  // broader localizing store-value parity.
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $ptr i32) (param $x i64) (result i32) (local $w i32)
        #|    local.get $ptr
        #|    local.get $x
        #|    i32.wrap_i64
        #|    local.tee $w
        #|    i32.store8
        #|    local.get $w))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected multi-use wrap-store boundary success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("wrap_i64"), msg=pretty)
  assert_true(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("i32.store8"), msg=pretty)
  assert_false(pretty.contains("i64.store8"), msg=pretty)
}

///|
test "optimize-instructions rewrites reinterpret stores to representation stores" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $ptr i32) (param $i32 i32) (param $i64 i64) (param $f32 f32) (param $f64 f64)
        #|    local.get $ptr
        #|    local.get $i32
        #|    f32.reinterpret_i32
        #|    f32.store
        #|    local.get $ptr
        #|    local.get $i64
        #|    f64.reinterpret_i64
        #|    f64.store
        #|    local.get $ptr
        #|    local.get $f32
        #|    i32.reinterpret_f32
        #|    i32.store
        #|    local.get $ptr
        #|    local.get $f64
        #|    i64.reinterpret_f64
        #|    i64.store))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected reinterpret-store optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  for
    op in [
      "f32.reinterpret_i32", "f64.reinterpret_i64", "i32.reinterpret_f32", "i64.reinterpret_f64",
    ] {
    assert_false(pretty.contains(op), msg="\{op} not folded: \{pretty}")
  }
  optimize_instructions_assert_strings_in_order(pretty, [
    "(local.get (Local 0))", "(local.get (Local 1))", "i32.store", "(local.get (Local 0))",
    "(local.get (Local 2))", "i64.store", "(local.get (Local 0))", "(local.get (Local 3))",
    "f32.store", "(local.get (Local 0))", "(local.get (Local 4))", "f64.store",
  ])
}

///|
test "optimize-instructions preserves memargs when rewriting reinterpret stores" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $ptr i32) (param $i32 i32) (param $i64 i64) (param $f32 f32) (param $f64 f64)
        #|    local.get $ptr
        #|    local.get $i32
        #|    f32.reinterpret_i32
        #|    f32.store offset=4 align=1
        #|    local.get $ptr
        #|    local.get $i64
        #|    f64.reinterpret_i64
        #|    f64.store offset=8 align=2
        #|    local.get $ptr
        #|    local.get $f32
        #|    i32.reinterpret_f32
        #|    i32.store offset=12 align=1
        #|    local.get $ptr
        #|    local.get $f64
        #|    i64.reinterpret_f64
        #|    i64.store offset=16 align=4))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected reinterpret-store memarg success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  for
    op in [
      "f32.reinterpret_i32", "f64.reinterpret_i64", "i32.reinterpret_f32", "i64.reinterpret_f64",
    ] {
    assert_false(pretty.contains(op), msg="\{op} not folded: \{pretty}")
  }
  optimize_instructions_assert_strings_in_order(pretty, [
    "i32.store align=U32(0) offset=U64(4)", "i64.store align=U32(1) offset=U64(8)",
    "f32.store align=U32(0) offset=U64(12)", "f64.store align=U32(2) offset=U64(16)",
  ])
}

///|
test "optimize-instructions intentionally keeps local-carried reinterpret-store boundary" {
  // Boundary-only OI-G classification: Binaryen `version_130`
  // `--optimize-instructions` keeps local-carried/shared reinterpret-store
  // spellings instead of rewriting them to representation stores
  // (`.tmp/oi-g-local-carried-reinterpret-store-probe.wat`). Starshine's
  // direct stored-value rewrite remains limited to direct one-use reinterpret
  // children, so this fixture prevents hiding broader shared-store parity.
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $ptr i32) (param $bits i32) (local $tmp f32)
        #|    local.get $ptr
        #|    local.get $bits
        #|    f32.reinterpret_i32
        #|    local.tee $tmp
        #|    f32.store)
        #|  (func (param $ptr i32) (param $bits i32) (local $tmp f32)
        #|    local.get $bits
        #|    f32.reinterpret_i32
        #|    local.set $tmp
        #|    local.get $ptr
        #|    local.get $tmp
        #|    f32.store))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected local-carried reinterpret-store boundary success, got \{err}",
      )
  }
  let tee_store = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(tee_store.contains("f32.reinterpret_i32"), msg=tee_store)
  assert_true(tee_store.contains("local.tee"), msg=tee_store)
  assert_true(tee_store.contains("f32.store"), msg=tee_store)
  assert_false(tee_store.contains("i32.store"), msg=tee_store)
  let local_store = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(local_store.contains("f32.reinterpret_i32"), msg=local_store)
  assert_true(local_store.contains("local.set"), msg=local_store)
  assert_true(local_store.contains("local.get"), msg=local_store)
  assert_true(local_store.contains("f32.store"), msg=local_store)
  assert_false(local_store.contains("i32.store"), msg=local_store)
}

///|
test "optimize-instructions rewrites reinterpret loads to representation loads" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $ptr i32) (result f32)
        #|    local.get $ptr
        #|    i32.load
        #|    f32.reinterpret_i32)
        #|  (func (param $ptr i32) (result f64)
        #|    local.get $ptr
        #|    i64.load
        #|    f64.reinterpret_i64)
        #|  (func (param $ptr i32) (result i32)
        #|    local.get $ptr
        #|    f32.load
        #|    i32.reinterpret_f32)
        #|  (func (param $ptr i32) (result i64)
        #|    local.get $ptr
        #|    f64.load
        #|    i64.reinterpret_f64))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected reinterpret-load optimize success, got \{err}")
  }
  for idx = 0U; idx < 4U; idx = idx + 1U {
    let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(idx))
    for
      op in [
        "f32.reinterpret_i32", "f64.reinterpret_i64", "i32.reinterpret_f32", "i64.reinterpret_f64",
      ] {
      assert_false(
        pretty.contains(op),
        msg="\{op} not folded in func \{idx}: \{pretty}",
      )
    }
  }
  optimize_instructions_assert_strings_in_order(
    optimized.pretty_print_func(@lib.FuncIdx::new(0U)),
    ["(local.get (Local 0))", "f32.load"],
  )
  optimize_instructions_assert_strings_in_order(
    optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
    ["(local.get (Local 0))", "f64.load"],
  )
  optimize_instructions_assert_strings_in_order(
    optimized.pretty_print_func(@lib.FuncIdx::new(2U)),
    ["(local.get (Local 0))", "i32.load"],
  )
  optimize_instructions_assert_strings_in_order(
    optimized.pretty_print_func(@lib.FuncIdx::new(3U)),
    ["(local.get (Local 0))", "i64.load"],
  )
}

///|
test "optimize-instructions preserves memargs when rewriting representation loads" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $ptr i32) (result f32)
        #|    local.get $ptr
        #|    i32.load offset=4 align=1
        #|    f32.reinterpret_i32)
        #|  (func (param $ptr i32) (result i64)
        #|    local.get $ptr
        #|    i32.load offset=8 align=2
        #|    i64.extend_i32_u)
        #|  (func (param $ptr i32) (result i64)
        #|    local.get $ptr
        #|    i32.load16_s offset=12 align=1
        #|    i64.extend_i32_s))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected load memarg rewrite success, got \{err}")
  }
  let reinterpret = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(reinterpret.contains("f32.reinterpret_i32"), msg=reinterpret)
  optimize_instructions_assert_strings_in_order(reinterpret, [
    "(local.get (Local 0))", "f32.load", "align=U32(0)", "offset=U64(4)",
  ])
  let extend_full = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(extend_full.contains("i64.extend_i32"), msg=extend_full)
  optimize_instructions_assert_strings_in_order(extend_full, [
    "(local.get (Local 0))", "i64.load32u", "align=U32(1)", "offset=U64(8)",
  ])
  let extend_narrow = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(extend_narrow.contains("i64.extend_i32"), msg=extend_narrow)
  optimize_instructions_assert_strings_in_order(extend_narrow, [
    "(local.get (Local 0))", "i64.load16s", "align=U32(0)", "offset=U64(12)",
  ])
}

///|
test "optimize-instructions intentionally keeps local-carried representation-load boundary" {
  // Boundary-only OI-G classification: Binaryen `version_130`
  // keeps local-carried/shared load-result spellings for the probed
  // reinterpret and i64.extend_i32 forms (`.tmp/oi-g-shared-reinterpret-load-probe.wat`
  // and `.tmp/oi-g-local-carried-extend-load-probe.wat`). Starshine's
  // representation-load rewrites remain limited to direct one-use load children.
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $ptr i32) (result f32) (local $tmp i32)
        #|    local.get $ptr
        #|    i32.load
        #|    local.tee $tmp
        #|    f32.reinterpret_i32
        #|    drop
        #|    local.get $tmp
        #|    f32.reinterpret_i32)
        #|  (func (param $ptr i32) (result i64) (local $tmp i32)
        #|    local.get $ptr
        #|    i32.load
        #|    local.tee $tmp
        #|    i64.extend_i32_u
        #|    drop
        #|    local.get $tmp
        #|    i64.extend_i32_s))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected local-carried representation-load boundary success, got \{err}",
      )
  }
  let reinterpret = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(reinterpret.contains("local.tee"), msg=reinterpret)
  assert_true(reinterpret.contains("f32.reinterpret_i32"), msg=reinterpret)
  assert_true(reinterpret.contains("i32.load"), msg=reinterpret)
  assert_false(reinterpret.contains("f32.load"), msg=reinterpret)
  let extend = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(extend.contains("local.tee"), msg=extend)
  assert_true(extend.contains("i64.extend_i32u"), msg=extend)
  assert_true(extend.contains("i64.extend_i32s"), msg=extend)
  assert_true(extend.contains("i32.load"), msg=extend)
  assert_false(extend.contains("i64.load32"), msg=extend)
}

///|
test "optimize-instructions rewrites i64.extend_i32 loads to representation loads" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $ptr i32) (result i64)
        #|    local.get $ptr
        #|    i32.load
        #|    i64.extend_i32_u)
        #|  (func (param $ptr i32) (result i64)
        #|    local.get $ptr
        #|    i32.load
        #|    i64.extend_i32_s)
        #|  (func (param $ptr i32) (result i64)
        #|    local.get $ptr
        #|    i32.load8_u
        #|    i64.extend_i32_u)
        #|  (func (param $ptr i32) (result i64)
        #|    local.get $ptr
        #|    i32.load8_s
        #|    i64.extend_i32_s)
        #|  (func (param $ptr i32) (result i64)
        #|    local.get $ptr
        #|    i32.load16_u
        #|    i64.extend_i32_u)
        #|  (func (param $ptr i32) (result i64)
        #|    local.get $ptr
        #|    i32.load16_s
        #|    i64.extend_i32_s)
        #|  (func (param $ptr i32) (result i64)
        #|    local.get $ptr
        #|    i32.load8_u
        #|    i64.extend_i32_s)
        #|  (func (param $ptr i32) (result i64)
        #|    local.get $ptr
        #|    i32.load16_u
        #|    i64.extend_i32_s))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected extend-load optimize success, got \{err}")
  }
  for idx = 0U; idx < 8U; idx = idx + 1U {
    let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(idx))
    assert_false(pretty.contains("i64.extend_i32"), msg=pretty)
  }
  optimize_instructions_assert_strings_in_order(
    optimized.pretty_print_func(@lib.FuncIdx::new(0U)),
    ["(local.get (Local 0))", "i64.load32u"],
  )
  optimize_instructions_assert_strings_in_order(
    optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
    ["(local.get (Local 0))", "i64.load32s"],
  )
  optimize_instructions_assert_strings_in_order(
    optimized.pretty_print_func(@lib.FuncIdx::new(2U)),
    ["(local.get (Local 0))", "i64.load8u"],
  )
  optimize_instructions_assert_strings_in_order(
    optimized.pretty_print_func(@lib.FuncIdx::new(3U)),
    ["(local.get (Local 0))", "i64.load8s"],
  )
  optimize_instructions_assert_strings_in_order(
    optimized.pretty_print_func(@lib.FuncIdx::new(4U)),
    ["(local.get (Local 0))", "i64.load16u"],
  )
  optimize_instructions_assert_strings_in_order(
    optimized.pretty_print_func(@lib.FuncIdx::new(5U)),
    ["(local.get (Local 0))", "i64.load16s"],
  )
  optimize_instructions_assert_strings_in_order(
    optimized.pretty_print_func(@lib.FuncIdx::new(6U)),
    ["(local.get (Local 0))", "i64.load8u"],
  )
  optimize_instructions_assert_strings_in_order(
    optimized.pretty_print_func(@lib.FuncIdx::new(7U)),
    ["(local.get (Local 0))", "i64.load16u"],
  )
}

///|
test "optimize-instructions keeps i64.extend_i32 before i64 narrow stores as a Binaryen OI parity boundary" {
  // Boundary-only OI-G classification: Binaryen `version_130`
  // `--optimize-instructions` does NOT fold `i64.store8` / `i64.store16` of an
  // `i64.extend_i32_u` / `i64.extend_i32_s` operand (probe
  // `.tmp/oi-g-wrap-store-probe.wat`). The reverse widening direction is
  // therefore not an OI gap; Starshine keeping the extend is correct parity.
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $ptr i32) (param $x i32)
        #|    local.get $ptr
        #|    local.get $x
        #|    i64.extend_i32_u
        #|    i64.store8
        #|    local.get $ptr
        #|    local.get $x
        #|    i64.extend_i32_s
        #|    i64.store8))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected extend-store optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i64.extend_i32u"), msg=pretty)
  assert_true(pretty.contains("i64.extend_i32s"), msg=pretty)
  assert_true(pretty.contains("i64.store8"), msg=pretty)
}

///|
test "optimize-instructions folds identity binary operands" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func $id (param $x i32) (param $y i64)
        #|    local.get $x
        #|    i32.const 0
        #|    i32.or
        #|    drop
        #|    local.get $x
        #|    i32.const -1
        #|    i32.and
        #|    drop
        #|    local.get $x
        #|    i32.const 0
        #|    i32.xor
        #|    drop
        #|    local.get $x
        #|    i32.const 1
        #|    i32.mul
        #|    drop
        #|    local.get $x
        #|    i32.const 0
        #|    i32.shl
        #|    drop
        #|    local.get $x
        #|    i32.const 0
        #|    i32.shr_u
        #|    drop
        #|    local.get $x
        #|    i32.const 0
        #|    i32.shr_s
        #|    drop
        #|    local.get $x
        #|    i32.const 0
        #|    i32.add
        #|    drop
        #|    local.get $x
        #|    i32.const 0
        #|    i32.sub
        #|    drop
        #|    local.get $y
        #|    i64.const 0
        #|    i64.or
        #|    drop
        #|    local.get $y
        #|    i64.const -1
        #|    i64.and
        #|    drop
        #|    local.get $y
        #|    i64.const 0
        #|    i64.xor
        #|    drop
        #|    local.get $y
        #|    i64.const 1
        #|    i64.mul
        #|    drop
        #|    local.get $y
        #|    i64.const 0
        #|    i64.shl
        #|    drop
        #|    local.get $y
        #|    i64.const 0
        #|    i64.shr_u
        #|    drop
        #|    local.get $y
        #|    i64.const 0
        #|    i64.add
        #|    drop
        #|    local.get $y
        #|    i64.const 0
        #|    i64.sub
        #|    drop)
        #|  (func $sub_zero_lhs (param $x i32) (result i32)
        #|    i32.const 0
        #|    local.get $x
        #|    i32.sub))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected identity-fold optimize success, got \{err}")
  }
  let id_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  // Every identity binary op folds to its non-constant operand.
  for
    op in [
      "i32.or", "i32.and", "i32.xor", "i32.mul", "i32.shl", "i32.shr_s", "i32.shr_u",
      "i32.add", "i32.sub", "i64.or", "i64.and", "i64.xor", "i64.mul", "i64.shl",
      "i64.shr_u", "i64.add", "i64.sub",
    ] {
    assert_false(id_pretty.contains(op), msg="\{op} not folded: \{id_pretty}")
  }
  // Boundary: sub(0, x) is -x, not x, so it must be kept.
  let sub_lhs = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(sub_lhs.contains("i32.sub"), msg=sub_lhs)
}

///|
test "optimize-instructions folds div/rem/rot identity operands" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (import "m" "effect" (func $effect (result i32)))
        #|  (func $id (param $x i32) (param $y i64)
        #|    local.get $x
        #|    i32.const 1
        #|    i32.div_s
        #|    drop
        #|    local.get $x
        #|    i32.const 1
        #|    i32.div_u
        #|    drop
        #|    local.get $x
        #|    i32.const 1
        #|    i32.rem_s
        #|    drop
        #|    local.get $x
        #|    i32.const 1
        #|    i32.rem_u
        #|    drop
        #|    local.get $x
        #|    i32.const 0
        #|    i32.rotl
        #|    drop
        #|    local.get $x
        #|    i32.const 0
        #|    i32.rotr
        #|    drop
        #|    local.get $y
        #|    i64.const 1
        #|    i64.div_s
        #|    drop
        #|    local.get $y
        #|    i64.const 1
        #|    i64.rem_s
        #|    drop
        #|    local.get $y
        #|    i64.const 0
        #|    i64.rotl
        #|    drop)
        #|  (func $div_lhs_one (param $x i32) (result i32)
        #|    i32.const 1
        #|    local.get $x
        #|    i32.div_s)
        #|  (func $rem_eff (result i32)
        #|    call $effect
        #|    i32.const 1
        #|    i32.rem_s))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected div/rem/rot identity optimize success, got \{err}")
  }
  let id_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  for
    op in [
      "i32.div_s", "i32.div_u", "i32.rem_s", "i32.rem_u", "i32.rotl", "i32.rotr",
      "i64.div_s", "i64.rem_s", "i64.rotl",
    ] {
    assert_false(id_pretty.contains(op), msg="\{op} not folded: \{id_pretty}")
  }
  // Boundary: div(1, x) is not x, so it must be kept.
  let div_lhs = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(div_lhs.contains("i32.div_s"), msg=div_lhs)
  // Boundary: rem(effect, 1) -> 0 would drop the effect, so it must be kept.
  let rem_eff = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(rem_eff.contains("i32.rem_s"), msg=rem_eff)
  assert_true(rem_eff.contains("call"), msg=rem_eff)
}

///|
test "optimize-instructions folds absorbing binary operands" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (import "m" "effect" (func $effect (result i32)))
        #|  (func $id (param $x i32) (param $y i64)
        #|    local.get $x
        #|    i32.const 0
        #|    i32.mul
        #|    drop
        #|    i32.const 0
        #|    local.get $x
        #|    i32.mul
        #|    drop
        #|    local.get $x
        #|    i32.const 0
        #|    i32.and
        #|    drop
        #|    local.get $x
        #|    i32.const -1
        #|    i32.rem_s
        #|    drop
        #|    local.get $y
        #|    i64.const 0
        #|    i64.mul
        #|    drop
        #|    i64.const 0
        #|    local.get $y
        #|    i64.mul
        #|    drop
        #|    local.get $y
        #|    i64.const 0
        #|    i64.and
        #|    drop
        #|    local.get $y
        #|    i64.const -1
        #|    i64.rem_s
        #|    drop)
        #|  (func $mul_eff (result i32)
        #|    call $effect
        #|    i32.const 0
        #|    i32.mul)
        #|  (func $and_eff (result i32)
        #|    call $effect
        #|    i32.const 0
        #|    i32.and)
        #|  (func $rem_neg1_eff (result i32)
        #|    call $effect
        #|    i32.const -1
        #|    i32.rem_s))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected absorbing-fold optimize success, got \{err}")
  }
  let id_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  for
    op in ["i32.mul", "i32.and", "i32.rem_s", "i64.mul", "i64.and", "i64.rem_s"] {
    assert_false(id_pretty.contains(op), msg="\{op} not folded: \{id_pretty}")
  }
  // Boundary: folding to zero would drop the effect, so effectful operands are kept.
  let mul_eff = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(mul_eff.contains("i32.mul"), msg=mul_eff)
  assert_true(mul_eff.contains("call"), msg=mul_eff)
  let and_eff = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(and_eff.contains("i32.and"), msg=and_eff)
  assert_true(and_eff.contains("call"), msg=and_eff)
  let rem_neg1_eff = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  assert_true(rem_neg1_eff.contains("i32.rem_s"), msg=rem_neg1_eff)
  assert_true(rem_neg1_eff.contains("call"), msg=rem_neg1_eff)
}

///|
test "optimize-instructions drops superset low-bit masks before narrow stores" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $ptr i32) (param $value32 i32) (param $value64 i64)
        #|    local.get $ptr
        #|    local.get $value32
        #|    i32.const 511
        #|    i32.and
        #|    i32.store8
        #|    local.get $ptr
        #|    local.get $value32
        #|    i32.const 131071
        #|    i32.and
        #|    i32.store16
        #|    local.get $ptr
        #|    local.get $value64
        #|    i64.const 511
        #|    i64.and
        #|    i64.store8
        #|    local.get $ptr
        #|    local.get $value64
        #|    i64.const 131071
        #|    i64.and
        #|    i64.store16
        #|    local.get $ptr
        #|    local.get $value64
        #|    i64.const 8589934591
        #|    i64.and
        #|    i64.store32))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected superset mask store optimize success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  // OI-G coverage/classification: Binaryen version_130 only drops the exact
  // i32 masks in this family, but storing a value masked with any superset of
  // the stored low bits is equivalent to storing the unmasked value. Starshine
  // intentionally keeps the smaller, already-implemented cleanup for both i32
  // and i64 narrow stores rather than matching Binaryen's larger output shape.
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
test "optimize-instructions intentionally keeps sign extensions before narrow stores" {
  // Binaryen version_130 optimize-instructions canonicalizes sign-extension shift
  // pairs to extension opcodes here, but does not drop the extension before the
  // narrow store. Keep this as an explicit OI-G boundary rather than claiming a
  // missing stored-value cleanup gap.
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $ptr i32) (param $value32 i32) (param $value64 i64)
        #|    local.get $ptr
        #|    local.get $value32
        #|    i32.extend8_s
        #|    i32.store8
        #|    local.get $ptr
        #|    local.get $value32
        #|    i32.extend16_s
        #|    i32.store16
        #|    local.get $ptr
        #|    local.get $value64
        #|    i64.extend16_s
        #|    i64.store16))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected narrow-store sign extension boundary success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.extend8s"), msg=pretty)
  assert_true(pretty.contains("i32.extend16s"), msg=pretty)
  assert_true(pretty.contains("i64.extend16s"), msg=pretty)
  assert_true(pretty.contains("i32.store8"), msg=pretty)
  assert_true(pretty.contains("i32.store16"), msg=pretty)
  assert_true(pretty.contains("i64.store16"), msg=pretty)
}

///|
test "optimize-instructions intentionally keeps signed loads before narrow stores" {
  // Boundary-only OI-G slice: Binaryen version_130 optimize-instructions keeps
  // signed loads feeding same-width narrow stores rather than changing their
  // spelling to unsigned loads. Lock that exact stored-value boundary so the
  // signed-load forms are not counted as a missing narrow-store cleanup gap.
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (memory 1)
        #|  (func (param $dst i32) (param $src i32)
        #|    local.get $dst
        #|    local.get $src
        #|    i32.load8_s
        #|    i32.store8
        #|    local.get $dst
        #|    local.get $src
        #|    i32.load16_s
        #|    i32.store16
        #|    local.get $dst
        #|    local.get $src
        #|    i64.load8_s
        #|    i64.store8
        #|    local.get $dst
        #|    local.get $src
        #|    i64.load16_s
        #|    i64.store16
        #|    local.get $dst
        #|    local.get $src
        #|    i64.load32_s
        #|    i64.store32))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected narrow-store signed-load boundary success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.load8s"), msg=pretty)
  assert_true(pretty.contains("i32.load16s"), msg=pretty)
  assert_true(pretty.contains("i64.load8s"), msg=pretty)
  assert_true(pretty.contains("i64.load16s"), msg=pretty)
  assert_true(pretty.contains("i64.load32s"), msg=pretty)
  assert_true(pretty.contains("i32.store8"), msg=pretty)
  assert_true(pretty.contains("i32.store16"), msg=pretty)
  assert_true(pretty.contains("i64.store8"), msg=pretty)
  assert_true(pretty.contains("i64.store16"), msg=pretty)
  assert_true(pretty.contains("i64.store32"), msg=pretty)
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
test "optimize-instructions folds pure struct.get of struct.new field values" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (type $s (struct (field i32) (field i64)))
        #|  (func (export "get0") (result i32)
        #|    i32.const 7
        #|    i64.const 9
        #|    struct.new $s
        #|    struct.get $s 0)
        #|  (func (export "get1") (result i64)
        #|    i32.const 7
        #|    i64.const 9
        #|    struct.new $s
        #|    struct.get $s 1))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected struct.get(struct.new) optimize success, got \{err}")
  }
  let get0 = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let get1 = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(get0.contains("struct.get"), msg=get0)
  assert_false(get0.contains("struct.new"), msg=get0)
  assert_true(get0.contains("I32(7)"), msg=get0)
  assert_false(get1.contains("struct.get"), msg=get1)
  assert_false(get1.contains("struct.new"), msg=get1)
  assert_true(get1.contains("I64(9)"), msg=get1)
}

///|
test "optimize-instructions folds struct.get of struct.new_default field defaults" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (type $s (struct
        #|    (field i32)
        #|    (field i64)
        #|    (field f32)
        #|    (field f64)
        #|    (field (ref null extern))))
        #|  (func (export "get_i32") (result i32)
        #|    struct.new_default $s
        #|    struct.get $s 0)
        #|  (func (export "get_i64") (result i64)
        #|    struct.new_default $s
        #|    struct.get $s 1)
        #|  (func (export "get_f32") (result f32)
        #|    struct.new_default $s
        #|    struct.get $s 2)
        #|  (func (export "get_f64") (result f64)
        #|    struct.new_default $s
        #|    struct.get $s 3)
        #|  (func (export "get_ref") (result externref)
        #|    struct.new_default $s
        #|    struct.get $s 4))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected struct.get(struct.new_default) optimize success, got \{err}",
      )
  }
  let get_i32 = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let get_i64 = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let get_f32 = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let get_f64 = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  let get_ref = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  assert_false(get_i32.contains("struct.get"), msg=get_i32)
  assert_false(get_i32.contains("struct.new_default"), msg=get_i32)
  assert_true(get_i32.contains("I32(0)"), msg=get_i32)
  assert_false(get_i64.contains("struct.get"), msg=get_i64)
  assert_false(get_i64.contains("struct.new_default"), msg=get_i64)
  assert_true(get_i64.contains("I64(0)"), msg=get_i64)
  assert_false(get_f32.contains("struct.get"), msg=get_f32)
  assert_false(get_f32.contains("struct.new_default"), msg=get_f32)
  assert_true(get_f32.contains("F32(0)"), msg=get_f32)
  assert_false(get_f64.contains("struct.get"), msg=get_f64)
  assert_false(get_f64.contains("struct.new_default"), msg=get_f64)
  assert_true(get_f64.contains("F64(0)"), msg=get_f64)
  assert_false(get_ref.contains("struct.get"), msg=get_ref)
  assert_false(get_ref.contains("struct.new_default"), msg=get_ref)
  assert_true(get_ref.contains("ref.null"), msg=get_ref)
}

///|
test "optimize-instructions folds packed struct.get_s and struct.get_u of struct.new_default defaults" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (type $s (struct (field i8) (field i16)))
        #|  (func (export "gets8") (result i32)
        #|    struct.new_default $s
        #|    struct.get_s $s 0)
        #|  (func (export "getu8") (result i32)
        #|    struct.new_default $s
        #|    struct.get_u $s 0)
        #|  (func (export "gets16") (result i32)
        #|    struct.new_default $s
        #|    struct.get_s $s 1)
        #|  (func (export "getu16") (result i32)
        #|    struct.new_default $s
        #|    struct.get_u $s 1))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected packed struct.get(struct.new_default) optimize success, got \{err}",
      )
  }
  for i = 0; i < 4; i = i + 1 {
    let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(i.to_uint()))
    assert_false(pretty.contains("struct.get"), msg=pretty)
    assert_false(pretty.contains("struct.new_default"), msg=pretty)
    assert_true(pretty.contains("I32(0)"), msg=pretty)
  }
}

///|
test "optimize-instructions folds packed struct.get_s and struct.get_u of struct.new field values" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (type $s (struct (field i32) (field i8) (field i16)))
        #|  (func (export "gets8") (param $x i32) (result i32)
        #|    i32.const 1
        #|    local.get $x
        #|    i32.const 2
        #|    struct.new $s
        #|    struct.get_s $s 1)
        #|  (func (export "getu16") (param $x i32) (result i32)
        #|    i32.const 1
        #|    i32.const 2
        #|    local.get $x
        #|    struct.new $s
        #|    struct.get_u $s 2)
        #|  (func (export "const_s8") (result i32)
        #|    i32.const 1
        #|    i32.const 255
        #|    i32.const 2
        #|    struct.new $s
        #|    struct.get_s $s 1)
        #|  (func (export "const_u16") (result i32)
        #|    i32.const 1
        #|    i32.const 2
        #|    i32.const 65535
        #|    struct.new $s
        #|    struct.get_u $s 2))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected packed struct.get(struct.new) optimize success, got \{err}",
      )
  }
  let gets8 = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let getu16 = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let const_s8 = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let const_u16 = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_false(gets8.contains("struct.get"), msg=gets8)
  assert_false(gets8.contains("struct.new"), msg=gets8)
  assert_true(gets8.contains("i32.extend8s"), msg=gets8)
  assert_false(getu16.contains("struct.get"), msg=getu16)
  assert_false(getu16.contains("struct.new"), msg=getu16)
  assert_true(getu16.contains("i32.and"), msg=getu16)
  assert_true(getu16.contains("I32(65535)"), msg=getu16)
  assert_false(const_s8.contains("struct.get"), msg=const_s8)
  assert_false(const_s8.contains("struct.new"), msg=const_s8)
  assert_true(const_s8.contains("I32(-1)"), msg=const_s8)
  assert_false(const_u16.contains("struct.get"), msg=const_u16)
  assert_false(const_u16.contains("struct.new"), msg=const_u16)
  assert_true(const_u16.contains("I32(65535)"), msg=const_u16)
}

///|
test "optimize-instructions folds tuple.extract of one-use tuple.make" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let tuple = @ir.hot_build_tuple_make(
    func,
    [@lib.ValType::i32(), @lib.ValType::i64()],
    [
      @ir.hot_build_local_get(func, 0),
      @ir.hot_build_const_i64(func, @lib.I64(9L)),
    ],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 0)
  @ir.hot_root_append(func, extract)

  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected tuple.extract optimize success, got \{err}")
  }

  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::LocalGet => ()
    _ =>
      fail("expected tuple.extract(tuple.make) to forward selected local.get")
  }
  @debug.assert_eq(@ir.hot_node_get(func, root).imm0, 0)
}

///|
test "optimize-instructions preserves selected trapping tuple.extract lane" {
  // OI-M selected-lane trap coverage: Binaryen `version_130`
  // `--optimize-instructions` preserves a selected `i32.load` lane from
  // `tuple.extract(tuple.make(...))` via tuple scratch in
  // `.tmp/oi-m-tuple-selected-trapping-probe.wat`. Starshine may keep the
  // smaller direct selected load, but it must not treat the selected trapping
  // lane as removable tuple debris.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
  let selected_load = @ir.hot_build_load(
    func,
    @lib.ValType::i32(),
    memarg,
    @ir.hot_build_local_get(func, 0),
  )
  @ir.hot_node_exact_instr_set(
    func,
    selected_load,
    @lib.Instruction::i32_load(memarg),
  )
  let tuple = @ir.hot_build_tuple_make(
    func,
    [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
    [
      selected_load,
      @ir.hot_build_const_i32(func, @lib.I32(7)),
      @ir.hot_build_const_i32(func, @lib.I32(9)),
    ],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 0)
  @ir.hot_root_append(func, extract)

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
        "expected selected trapping tuple lane forwarding success, got \{err}",
      )
  }

  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Load => ()
    other =>
      fail(
        "expected selected trapping tuple lane to remain a load, got \{other}",
      )
  }
  match @ir.hot_node_exact_instr(func, root) {
    Some(@lib.Instruction::I32Load(_)) => ()
    _ => fail("expected selected trapping tuple lane to keep exact i32.load")
  }
}

///|
test "optimize-instructions preserves selected trapping tuple.extract lane with effectful sibling" {
  // OI-M selected-lane/effect-order coverage: Binaryen `version_130`
  // `--optimize-instructions` preserves a selected trapping `i32.load` through
  // tuple scratch before dropping a later effectful sibling in
  // `.tmp/oi-m-tuple-selected-trapping-with-sibling-probe.wat`. Starshine's
  // direct-HOT localizer may use a smaller block, but the selected load must be
  // evaluated before the sibling effect and reloaded as the final value.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
  let selected_load = @ir.hot_build_load(
    func,
    @lib.ValType::i32(),
    memarg,
    @ir.hot_build_local_get(func, 0),
  )
  @ir.hot_node_exact_instr_set(
    func,
    selected_load,
    @lib.Instruction::i32_load(memarg),
  )
  let sibling_call = @ir.hot_build_call(func, 0, [@lib.ValType::i64()], [])
  let tuple = @ir.hot_build_tuple_make(
    func,
    [@lib.ValType::i32(), @lib.ValType::i64(), @lib.ValType::i32()],
    [selected_load, sibling_call, @ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 0)
  @ir.hot_root_append(func, extract)

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
        "expected selected trapping tuple sibling localization success, got \{err}",
      )
  }

  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block => ()
    _ =>
      fail("expected selected trapping sibling tuple.extract to become a block")
  }
  let body = @ir.hot_region_body_ref(func, root)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 3)
  let selected_set = @ir.hot_region_get(func, body, 0)
  let sibling_drop = @ir.hot_region_get(func, body, 1)
  let selected_get = @ir.hot_region_get(func, body, 2)
  match @ir.hot_node_get(func, selected_set).op {
    @ir.HotOp::LocalSet => ()
    _ => fail("expected selected trapping lane to be stored before sibling")
  }
  let stored_load = @ir.hot_child_get(func, selected_set, 0)
  match @ir.hot_node_exact_instr(func, stored_load) {
    Some(@lib.Instruction::I32Load(_)) => ()
    _ => fail("expected localized selected lane to keep exact i32.load")
  }
  match @ir.hot_node_get(func, sibling_drop).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected effectful sibling to be dropped after selected load")
  }
  let dropped_call = @ir.hot_child_get(func, sibling_drop, 0)
  match @ir.hot_node_get(func, dropped_call).op {
    @ir.HotOp::Call => ()
    _ => fail("expected effectful tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, selected_get).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected selected trapping lane to reload after sibling")
  }
  @debug.assert_eq(
    @ir.hot_node_get(func, selected_get).imm0,
    @ir.hot_node_get(func, selected_set).imm0,
  )
}

///|
test "optimize-instructions preserves selected trapping tuple.extract lane with earlier effectful sibling" {
  // OI-M selected-lane/effect-order coverage: Binaryen `version_130`
  // `--optimize-instructions` drops an earlier effectful sibling before
  // localizing a selected trapping `i32.load` through tuple scratch in
  // `.tmp/oi-m-tuple-earlier-sibling-selected-trapping-probe.wat`. Starshine's
  // direct-HOT localizer may use a smaller block than Binaryen's local.tee/drop,
  // but the earlier effect must stay before the selected load.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let earlier_call = @ir.hot_build_call(func, 0, [@lib.ValType::i64()], [])
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
  let selected_load = @ir.hot_build_load(
    func,
    @lib.ValType::i32(),
    memarg,
    @ir.hot_build_local_get(func, 0),
  )
  @ir.hot_node_exact_instr_set(
    func,
    selected_load,
    @lib.Instruction::i32_load(memarg),
  )
  let tuple = @ir.hot_build_tuple_make(
    func,
    [@lib.ValType::i64(), @lib.ValType::i32(), @lib.ValType::i32()],
    [earlier_call, selected_load, @ir.hot_build_const_i32(func, @lib.I32(7))],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 1)
  @ir.hot_root_append(func, extract)

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
        "expected selected trapping tuple earlier-sibling localization success, got \{err}",
      )
  }

  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block => ()
    _ =>
      fail(
        "expected selected trapping earlier-sibling tuple.extract to become a block",
      )
  }
  let body = @ir.hot_region_body_ref(func, root)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 2)
  let earlier_drop = @ir.hot_region_get(func, body, 0)
  let selected_load_result = @ir.hot_region_get(func, body, 1)
  match @ir.hot_node_get(func, earlier_drop).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected earlier effectful sibling to be dropped first")
  }
  let dropped_call = @ir.hot_child_get(func, earlier_drop, 0)
  match @ir.hot_node_get(func, dropped_call).op {
    @ir.HotOp::Call => ()
    _ => fail("expected earlier tuple sibling call to stay available")
  }
  match @ir.hot_node_exact_instr(func, selected_load_result) {
    Some(@lib.Instruction::I32Load(_)) => ()
    _ => fail("expected selected trapping lane to remain an exact i32.load")
  }
}

///|
test "optimize-instructions preserves selected trapping tuple.extract lane with two earlier siblings" {
  // OI-M selected-lane/effect-order coverage: Binaryen `version_130`
  // `--optimize-instructions` drops two earlier effectful siblings before
  // localizing a selected trapping `i32.load` through tuple scratch in
  // `.tmp/oi-m-tuple-selected-trapping-two-earlier-probe.wat`. Starshine's
  // direct-HOT localizer may return the selected load directly because no later
  // effect can reorder after it, but both earlier effects must stay before it.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let earlier_call_a = @ir.hot_build_call(func, 0, [@lib.ValType::i64()], [])
  let earlier_call_b = @ir.hot_build_call(func, 1, [@lib.ValType::i64()], [])
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
  let selected_load = @ir.hot_build_load(
    func,
    @lib.ValType::i32(),
    memarg,
    @ir.hot_build_local_get(func, 0),
  )
  @ir.hot_node_exact_instr_set(
    func,
    selected_load,
    @lib.Instruction::i32_load(memarg),
  )
  let tuple = @ir.hot_build_tuple_make(
    func,
    [
      @lib.ValType::i64(),
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ],
    [
      earlier_call_a,
      earlier_call_b,
      selected_load,
      @ir.hot_build_const_i32(func, @lib.I32(7)),
    ],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 2)
  @ir.hot_root_append(func, extract)

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
        "expected selected trapping tuple two-earlier-sibling localization success, got \{err}",
      )
  }

  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block => ()
    _ =>
      fail(
        "expected selected trapping two-earlier-sibling tuple.extract to become a block",
      )
  }
  let body = @ir.hot_region_body_ref(func, root)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 3)
  let earlier_drop_a = @ir.hot_region_get(func, body, 0)
  let earlier_drop_b = @ir.hot_region_get(func, body, 1)
  let selected_load_result = @ir.hot_region_get(func, body, 2)
  match @ir.hot_node_get(func, earlier_drop_a).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected first earlier effectful sibling to be dropped first")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, earlier_drop_a, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected first earlier tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, earlier_drop_b).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected second earlier effectful sibling to be dropped second")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, earlier_drop_b, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected second earlier tuple sibling call to stay available")
  }
  match @ir.hot_node_exact_instr(func, selected_load_result) {
    Some(@lib.Instruction::I32Load(_)) => ()
    _ => fail("expected selected trapping lane to remain an exact i32.load")
  }
}

///|
test "optimize-instructions preserves selected trapping tuple.extract lane with two earlier and one later siblings" {
  // OI-M selected-lane/effect-order coverage: Binaryen `version_130`
  // `--optimize-instructions` drops two earlier siblings, localizes the selected
  // trapping `i32.load`, drops one later sibling, and reloads the selected lane
  // in `.tmp/oi-m-tuple-selected-trapping-two-earlier-one-later-probe.wat`.
  // Starshine's direct-HOT localizer should preserve the same order.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let earlier_call_a = @ir.hot_build_call(func, 0, [@lib.ValType::i64()], [])
  let earlier_call_b = @ir.hot_build_call(func, 1, [@lib.ValType::i64()], [])
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
  let selected_load = @ir.hot_build_load(
    func,
    @lib.ValType::i32(),
    memarg,
    @ir.hot_build_local_get(func, 0),
  )
  @ir.hot_node_exact_instr_set(
    func,
    selected_load,
    @lib.Instruction::i32_load(memarg),
  )
  let later_call = @ir.hot_build_call(func, 2, [@lib.ValType::i32()], [])
  let pure_later = @ir.hot_build_const_i32(func, @lib.I32(7))
  let tuple = @ir.hot_build_tuple_make(
    func,
    [
      @lib.ValType::i64(),
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ],
    [earlier_call_a, earlier_call_b, selected_load, later_call, pure_later],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 2)
  @ir.hot_root_append(func, extract)

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
        "expected selected trapping tuple two-earlier/one-later-sibling localization success, got \{err}",
      )
  }

  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block => ()
    _ =>
      fail(
        "expected selected trapping two-earlier/one-later-sibling tuple.extract to become a block",
      )
  }
  let body = @ir.hot_region_body_ref(func, root)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 5)
  let earlier_drop_a = @ir.hot_region_get(func, body, 0)
  let earlier_drop_b = @ir.hot_region_get(func, body, 1)
  let selected_set = @ir.hot_region_get(func, body, 2)
  let later_drop = @ir.hot_region_get(func, body, 3)
  let selected_get = @ir.hot_region_get(func, body, 4)
  match @ir.hot_node_get(func, earlier_drop_a).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected first earlier effectful sibling to be dropped first")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, earlier_drop_a, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected first earlier tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, earlier_drop_b).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected second earlier effectful sibling to be dropped second")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, earlier_drop_b, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected second earlier tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, selected_set).op {
    @ir.HotOp::LocalSet => ()
    _ =>
      fail("expected selected trapping lane to be stored before later sibling")
  }
  let stored_load = @ir.hot_child_get(func, selected_set, 0)
  match @ir.hot_node_exact_instr(func, stored_load) {
    Some(@lib.Instruction::I32Load(_)) => ()
    _ => fail("expected localized selected lane to keep exact i32.load")
  }
  match @ir.hot_node_get(func, later_drop).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail("expected later effectful sibling to be dropped after selected load")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, selected_get).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected selected trapping lane to reload after later sibling")
  }
  @debug.assert_eq(
    @ir.hot_node_get(func, selected_get).imm0,
    @ir.hot_node_get(func, selected_set).imm0,
  )
}

///|
test "optimize-instructions preserves selected trapping tuple.extract lane with two earlier and two later siblings" {
  // OI-M selected-lane/effect-order coverage: Binaryen `version_130`
  // `--optimize-instructions` drops two earlier siblings, localizes the selected
  // trapping `i32.load`, drops two later siblings, and reloads the selected lane
  // in `.tmp/oi-m-tuple-selected-trapping-two-earlier-two-later-probe.wat`.
  // Starshine's direct-HOT localizer should preserve the same effect/trap order.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let earlier_call_a = @ir.hot_build_call(func, 0, [@lib.ValType::i64()], [])
  let earlier_call_b = @ir.hot_build_call(func, 1, [@lib.ValType::i64()], [])
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
  let selected_load = @ir.hot_build_load(
    func,
    @lib.ValType::i32(),
    memarg,
    @ir.hot_build_local_get(func, 0),
  )
  @ir.hot_node_exact_instr_set(
    func,
    selected_load,
    @lib.Instruction::i32_load(memarg),
  )
  let later_call_a = @ir.hot_build_call(func, 2, [@lib.ValType::i32()], [])
  let later_call_b = @ir.hot_build_call(func, 3, [@lib.ValType::i32()], [])
  let tuple = @ir.hot_build_tuple_make(
    func,
    [
      @lib.ValType::i64(),
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ],
    [earlier_call_a, earlier_call_b, selected_load, later_call_a, later_call_b],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 2)
  @ir.hot_root_append(func, extract)

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
        "expected selected trapping tuple two-earlier/two-later-sibling localization success, got \{err}",
      )
  }

  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block => ()
    _ =>
      fail(
        "expected selected trapping two-earlier/two-later-sibling tuple.extract to become a block",
      )
  }
  let body = @ir.hot_region_body_ref(func, root)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 6)
  let earlier_drop_a = @ir.hot_region_get(func, body, 0)
  let earlier_drop_b = @ir.hot_region_get(func, body, 1)
  let selected_set = @ir.hot_region_get(func, body, 2)
  let later_drop_a = @ir.hot_region_get(func, body, 3)
  let later_drop_b = @ir.hot_region_get(func, body, 4)
  let selected_get = @ir.hot_region_get(func, body, 5)
  match @ir.hot_node_get(func, earlier_drop_a).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected first earlier effectful sibling to be dropped first")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, earlier_drop_a, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected first earlier tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, earlier_drop_b).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected second earlier effectful sibling to be dropped second")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, earlier_drop_b, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected second earlier tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, selected_set).op {
    @ir.HotOp::LocalSet => ()
    _ =>
      fail("expected selected trapping lane to be stored before later siblings")
  }
  let stored_load = @ir.hot_child_get(func, selected_set, 0)
  match @ir.hot_node_exact_instr(func, stored_load) {
    Some(@lib.Instruction::I32Load(_)) => ()
    _ => fail("expected localized selected lane to keep exact i32.load")
  }
  match @ir.hot_node_get(func, later_drop_a).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected first later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_a, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected first later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_b).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected second later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_b, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected second later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, selected_get).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected selected trapping lane to reload after later siblings")
  }
  @debug.assert_eq(
    @ir.hot_node_get(func, selected_get).imm0,
    @ir.hot_node_get(func, selected_set).imm0,
  )
}

///|
test "optimize-instructions preserves selected trapping tuple.extract lane with two earlier and three later siblings" {
  // OI-M selected-lane/effect-order coverage: Binaryen `version_130`
  // `--optimize-instructions` drops two earlier siblings, localizes the selected
  // trapping `i32.load`, drops three later siblings, and reloads the selected lane
  // in `.tmp/oi-m-tuple-selected-trapping-two-earlier-three-later-probe.wat`.
  // Starshine's direct-HOT localizer should preserve the same effect/trap order.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let earlier_call_a = @ir.hot_build_call(func, 0, [@lib.ValType::i64()], [])
  let earlier_call_b = @ir.hot_build_call(func, 1, [@lib.ValType::i64()], [])
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
  let selected_load = @ir.hot_build_load(
    func,
    @lib.ValType::i32(),
    memarg,
    @ir.hot_build_local_get(func, 0),
  )
  @ir.hot_node_exact_instr_set(
    func,
    selected_load,
    @lib.Instruction::i32_load(memarg),
  )
  let later_call_a = @ir.hot_build_call(func, 2, [@lib.ValType::i32()], [])
  let later_call_b = @ir.hot_build_call(func, 3, [@lib.ValType::i32()], [])
  let later_call_c = @ir.hot_build_call(func, 4, [@lib.ValType::i32()], [])
  let tuple = @ir.hot_build_tuple_make(
    func,
    [
      @lib.ValType::i64(),
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ],
    [
      earlier_call_a, earlier_call_b, selected_load, later_call_a, later_call_b,
      later_call_c,
    ],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 2)
  @ir.hot_root_append(func, extract)

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
        "expected selected trapping tuple two-earlier/three-later-sibling localization success, got \{err}",
      )
  }

  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block => ()
    _ =>
      fail(
        "expected selected trapping two-earlier/three-later-sibling tuple.extract to become a block",
      )
  }
  let body = @ir.hot_region_body_ref(func, root)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 7)
  let earlier_drop_a = @ir.hot_region_get(func, body, 0)
  let earlier_drop_b = @ir.hot_region_get(func, body, 1)
  let selected_set = @ir.hot_region_get(func, body, 2)
  let later_drop_a = @ir.hot_region_get(func, body, 3)
  let later_drop_b = @ir.hot_region_get(func, body, 4)
  let later_drop_c = @ir.hot_region_get(func, body, 5)
  let selected_get = @ir.hot_region_get(func, body, 6)
  match @ir.hot_node_get(func, earlier_drop_a).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected first earlier effectful sibling to be dropped first")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, earlier_drop_a, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected first earlier tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, earlier_drop_b).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected second earlier effectful sibling to be dropped second")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, earlier_drop_b, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected second earlier tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, selected_set).op {
    @ir.HotOp::LocalSet => ()
    _ =>
      fail("expected selected trapping lane to be stored before later siblings")
  }
  let stored_load = @ir.hot_child_get(func, selected_set, 0)
  match @ir.hot_node_exact_instr(func, stored_load) {
    Some(@lib.Instruction::I32Load(_)) => ()
    _ => fail("expected localized selected lane to keep exact i32.load")
  }
  match @ir.hot_node_get(func, later_drop_a).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected first later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_a, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected first later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_b).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected second later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_b, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected second later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_c).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected third later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_c, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected third later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, selected_get).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected selected trapping lane to reload after later siblings")
  }
  @debug.assert_eq(
    @ir.hot_node_get(func, selected_get).imm0,
    @ir.hot_node_get(func, selected_set).imm0,
  )
}

///|
test "optimize-instructions preserves selected trapping tuple.extract lane with two earlier and four later siblings" {
  // OI-M selected-lane/effect-order coverage: Binaryen `version_130`
  // `--optimize-instructions` drops two earlier siblings, localizes the selected
  // trapping `i32.load`, drops four later siblings, and reloads the selected lane
  // in `.tmp/oi-m-tuple-selected-trapping-two-earlier-four-later-probe.wat`.
  // Starshine's direct-HOT localizer should preserve the same effect/trap order.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let earlier_call_a = @ir.hot_build_call(func, 0, [@lib.ValType::i64()], [])
  let earlier_call_b = @ir.hot_build_call(func, 1, [@lib.ValType::i64()], [])
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
  let selected_load = @ir.hot_build_load(
    func,
    @lib.ValType::i32(),
    memarg,
    @ir.hot_build_local_get(func, 0),
  )
  @ir.hot_node_exact_instr_set(
    func,
    selected_load,
    @lib.Instruction::i32_load(memarg),
  )
  let later_call_a = @ir.hot_build_call(func, 2, [@lib.ValType::i32()], [])
  let later_call_b = @ir.hot_build_call(func, 3, [@lib.ValType::i32()], [])
  let later_call_c = @ir.hot_build_call(func, 4, [@lib.ValType::i32()], [])
  let later_call_d = @ir.hot_build_call(func, 5, [@lib.ValType::i32()], [])
  let tuple = @ir.hot_build_tuple_make(
    func,
    [
      @lib.ValType::i64(),
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ],
    [
      earlier_call_a, earlier_call_b, selected_load, later_call_a, later_call_b,
      later_call_c, later_call_d,
    ],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 2)
  @ir.hot_root_append(func, extract)

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
        "expected selected trapping tuple two-earlier/four-later-sibling localization success, got \{err}",
      )
  }

  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block => ()
    _ =>
      fail(
        "expected selected trapping two-earlier/four-later-sibling tuple.extract to become a block",
      )
  }
  let body = @ir.hot_region_body_ref(func, root)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 8)
  let earlier_drop_a = @ir.hot_region_get(func, body, 0)
  let earlier_drop_b = @ir.hot_region_get(func, body, 1)
  let selected_set = @ir.hot_region_get(func, body, 2)
  let later_drop_a = @ir.hot_region_get(func, body, 3)
  let later_drop_b = @ir.hot_region_get(func, body, 4)
  let later_drop_c = @ir.hot_region_get(func, body, 5)
  let later_drop_d = @ir.hot_region_get(func, body, 6)
  let selected_get = @ir.hot_region_get(func, body, 7)
  match @ir.hot_node_get(func, earlier_drop_a).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected first earlier effectful sibling to be dropped first")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, earlier_drop_a, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected first earlier tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, earlier_drop_b).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected second earlier effectful sibling to be dropped second")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, earlier_drop_b, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected second earlier tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, selected_set).op {
    @ir.HotOp::LocalSet => ()
    _ =>
      fail("expected selected trapping lane to be stored before later siblings")
  }
  let stored_load = @ir.hot_child_get(func, selected_set, 0)
  match @ir.hot_node_exact_instr(func, stored_load) {
    Some(@lib.Instruction::I32Load(_)) => ()
    _ => fail("expected localized selected lane to keep exact i32.load")
  }
  match @ir.hot_node_get(func, later_drop_a).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected first later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_a, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected first later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_b).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected second later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_b, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected second later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_c).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected third later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_c, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected third later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_d).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected fourth later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_d, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected fourth later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, selected_get).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected selected trapping lane to reload after later siblings")
  }
  @debug.assert_eq(
    @ir.hot_node_get(func, selected_get).imm0,
    @ir.hot_node_get(func, selected_set).imm0,
  )
}

///|
test "optimize-instructions preserves selected trapping tuple.extract lane with two earlier and five later siblings" {
  // OI-M selected-lane/effect-order coverage: Binaryen `version_130`
  // `--optimize-instructions` drops two earlier siblings, localizes the selected
  // trapping `i32.load`, drops five later siblings, and reloads the selected lane
  // in `.tmp/oi-m-tuple-selected-trapping-two-earlier-five-later-probe.wat`.
  // Starshine's direct-HOT localizer should preserve the same effect/trap order.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let earlier_call_a = @ir.hot_build_call(func, 0, [@lib.ValType::i64()], [])
  let earlier_call_b = @ir.hot_build_call(func, 1, [@lib.ValType::i64()], [])
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
  let selected_load = @ir.hot_build_load(
    func,
    @lib.ValType::i32(),
    memarg,
    @ir.hot_build_local_get(func, 0),
  )
  @ir.hot_node_exact_instr_set(
    func,
    selected_load,
    @lib.Instruction::i32_load(memarg),
  )
  let later_call_a = @ir.hot_build_call(func, 2, [@lib.ValType::i32()], [])
  let later_call_b = @ir.hot_build_call(func, 3, [@lib.ValType::i32()], [])
  let later_call_c = @ir.hot_build_call(func, 4, [@lib.ValType::i32()], [])
  let later_call_d = @ir.hot_build_call(func, 5, [@lib.ValType::i32()], [])
  let later_call_e = @ir.hot_build_call(func, 6, [@lib.ValType::i32()], [])
  let tuple = @ir.hot_build_tuple_make(
    func,
    [
      @lib.ValType::i64(),
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ],
    [
      earlier_call_a, earlier_call_b, selected_load, later_call_a, later_call_b,
      later_call_c, later_call_d, later_call_e,
    ],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 2)
  @ir.hot_root_append(func, extract)

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
        "expected selected trapping tuple two-earlier/five-later-sibling localization success, got \{err}",
      )
  }

  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block => ()
    _ =>
      fail(
        "expected selected trapping two-earlier/five-later-sibling tuple.extract to become a block",
      )
  }
  let body = @ir.hot_region_body_ref(func, root)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 9)
  let earlier_drop_a = @ir.hot_region_get(func, body, 0)
  let earlier_drop_b = @ir.hot_region_get(func, body, 1)
  let selected_set = @ir.hot_region_get(func, body, 2)
  let later_drop_a = @ir.hot_region_get(func, body, 3)
  let later_drop_b = @ir.hot_region_get(func, body, 4)
  let later_drop_c = @ir.hot_region_get(func, body, 5)
  let later_drop_d = @ir.hot_region_get(func, body, 6)
  let later_drop_e = @ir.hot_region_get(func, body, 7)
  let selected_get = @ir.hot_region_get(func, body, 8)
  match @ir.hot_node_get(func, earlier_drop_a).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected first earlier effectful sibling to be dropped first")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, earlier_drop_a, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected first earlier tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, earlier_drop_b).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected second earlier effectful sibling to be dropped second")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, earlier_drop_b, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected second earlier tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, selected_set).op {
    @ir.HotOp::LocalSet => ()
    _ =>
      fail("expected selected trapping lane to be stored before later siblings")
  }
  let stored_load = @ir.hot_child_get(func, selected_set, 0)
  match @ir.hot_node_exact_instr(func, stored_load) {
    Some(@lib.Instruction::I32Load(_)) => ()
    _ => fail("expected localized selected lane to keep exact i32.load")
  }
  match @ir.hot_node_get(func, later_drop_a).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected first later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_a, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected first later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_b).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected second later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_b, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected second later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_c).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected third later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_c, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected third later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_d).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected fourth later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_d, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected fourth later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_e).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected fifth later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_e, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected fifth later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, selected_get).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected selected trapping lane to reload after later siblings")
  }
  @debug.assert_eq(
    @ir.hot_node_get(func, selected_get).imm0,
    @ir.hot_node_get(func, selected_set).imm0,
  )
}

///|
test "optimize-instructions preserves selected trapping tuple.extract lane with two earlier and six later siblings" {
  // OI-M selected-lane/effect-order coverage: Binaryen `version_130`
  // `--optimize-instructions` drops two earlier siblings, localizes the selected
  // trapping `i32.load`, drops six later siblings, and reloads the selected lane
  // in `.tmp/oi-m-tuple-selected-trapping-two-earlier-six-later-probe.wat`.
  // Starshine's direct-HOT localizer should preserve the same effect/trap order.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let earlier_call_a = @ir.hot_build_call(func, 0, [@lib.ValType::i64()], [])
  let earlier_call_b = @ir.hot_build_call(func, 1, [@lib.ValType::i64()], [])
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
  let selected_load = @ir.hot_build_load(
    func,
    @lib.ValType::i32(),
    memarg,
    @ir.hot_build_local_get(func, 0),
  )
  @ir.hot_node_exact_instr_set(
    func,
    selected_load,
    @lib.Instruction::i32_load(memarg),
  )
  let later_call_a = @ir.hot_build_call(func, 2, [@lib.ValType::i32()], [])
  let later_call_b = @ir.hot_build_call(func, 3, [@lib.ValType::i32()], [])
  let later_call_c = @ir.hot_build_call(func, 4, [@lib.ValType::i32()], [])
  let later_call_d = @ir.hot_build_call(func, 5, [@lib.ValType::i32()], [])
  let later_call_e = @ir.hot_build_call(func, 6, [@lib.ValType::i32()], [])
  let later_call_f = @ir.hot_build_call(func, 7, [@lib.ValType::i32()], [])
  let tuple = @ir.hot_build_tuple_make(
    func,
    [
      @lib.ValType::i64(),
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ],
    [
      earlier_call_a, earlier_call_b, selected_load, later_call_a, later_call_b,
      later_call_c, later_call_d, later_call_e, later_call_f,
    ],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 2)
  @ir.hot_root_append(func, extract)

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
        "expected selected trapping tuple two-earlier/six-later-sibling localization success, got \{err}",
      )
  }

  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block => ()
    _ =>
      fail(
        "expected selected trapping two-earlier/six-later-sibling tuple.extract to become a block",
      )
  }
  let body = @ir.hot_region_body_ref(func, root)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 10)
  let earlier_drop_a = @ir.hot_region_get(func, body, 0)
  let earlier_drop_b = @ir.hot_region_get(func, body, 1)
  let selected_set = @ir.hot_region_get(func, body, 2)
  let later_drop_a = @ir.hot_region_get(func, body, 3)
  let later_drop_b = @ir.hot_region_get(func, body, 4)
  let later_drop_c = @ir.hot_region_get(func, body, 5)
  let later_drop_d = @ir.hot_region_get(func, body, 6)
  let later_drop_e = @ir.hot_region_get(func, body, 7)
  let later_drop_f = @ir.hot_region_get(func, body, 8)
  let selected_get = @ir.hot_region_get(func, body, 9)
  match @ir.hot_node_get(func, earlier_drop_a).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected first earlier effectful sibling to be dropped first")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, earlier_drop_a, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected first earlier tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, earlier_drop_b).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected second earlier effectful sibling to be dropped second")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, earlier_drop_b, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected second earlier tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, selected_set).op {
    @ir.HotOp::LocalSet => ()
    _ =>
      fail("expected selected trapping lane to be stored before later siblings")
  }
  let stored_load = @ir.hot_child_get(func, selected_set, 0)
  match @ir.hot_node_exact_instr(func, stored_load) {
    Some(@lib.Instruction::I32Load(_)) => ()
    _ => fail("expected localized selected lane to keep exact i32.load")
  }
  match @ir.hot_node_get(func, later_drop_a).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected first later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_a, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected first later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_b).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected second later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_b, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected second later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_c).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected third later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_c, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected third later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_d).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected fourth later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_d, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected fourth later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_e).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected fifth later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_e, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected fifth later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_f).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected sixth later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_f, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected sixth later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, selected_get).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected selected trapping lane to reload after later siblings")
  }
  @debug.assert_eq(
    @ir.hot_node_get(func, selected_get).imm0,
    @ir.hot_node_get(func, selected_set).imm0,
  )
}

///|
test "optimize-instructions preserves selected trapping tuple.extract lane with two earlier and seven later siblings" {
  // OI-M selected-lane/effect-order coverage: Binaryen `version_130`
  // `--optimize-instructions` drops two earlier siblings, localizes the selected
  // trapping `i32.load`, drops seven later siblings, and reloads the selected lane
  // in `.tmp/oi-m-tuple-selected-trapping-two-earlier-seven-later-probe.wat`.
  // Starshine's direct-HOT localizer should preserve the same effect/trap order.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let earlier_call_a = @ir.hot_build_call(func, 0, [@lib.ValType::i64()], [])
  let earlier_call_b = @ir.hot_build_call(func, 1, [@lib.ValType::i64()], [])
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
  let selected_load = @ir.hot_build_load(
    func,
    @lib.ValType::i32(),
    memarg,
    @ir.hot_build_local_get(func, 0),
  )
  @ir.hot_node_exact_instr_set(
    func,
    selected_load,
    @lib.Instruction::i32_load(memarg),
  )
  let later_call_a = @ir.hot_build_call(func, 2, [@lib.ValType::i32()], [])
  let later_call_b = @ir.hot_build_call(func, 3, [@lib.ValType::i32()], [])
  let later_call_c = @ir.hot_build_call(func, 4, [@lib.ValType::i32()], [])
  let later_call_d = @ir.hot_build_call(func, 5, [@lib.ValType::i32()], [])
  let later_call_e = @ir.hot_build_call(func, 6, [@lib.ValType::i32()], [])
  let later_call_f = @ir.hot_build_call(func, 7, [@lib.ValType::i32()], [])
  let later_call_g = @ir.hot_build_call(func, 8, [@lib.ValType::i32()], [])
  let tuple = @ir.hot_build_tuple_make(
    func,
    [
      @lib.ValType::i64(),
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ],
    [
      earlier_call_a, earlier_call_b, selected_load, later_call_a, later_call_b,
      later_call_c, later_call_d, later_call_e, later_call_f, later_call_g,
    ],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 2)
  @ir.hot_root_append(func, extract)

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
        "expected selected trapping tuple two-earlier/seven-later-sibling localization success, got \{err}",
      )
  }

  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block => ()
    _ =>
      fail(
        "expected selected trapping two-earlier/seven-later-sibling tuple.extract to become a block",
      )
  }
  let body = @ir.hot_region_body_ref(func, root)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 11)
  let earlier_drop_a = @ir.hot_region_get(func, body, 0)
  let earlier_drop_b = @ir.hot_region_get(func, body, 1)
  let selected_set = @ir.hot_region_get(func, body, 2)
  let later_drop_a = @ir.hot_region_get(func, body, 3)
  let later_drop_b = @ir.hot_region_get(func, body, 4)
  let later_drop_c = @ir.hot_region_get(func, body, 5)
  let later_drop_d = @ir.hot_region_get(func, body, 6)
  let later_drop_e = @ir.hot_region_get(func, body, 7)
  let later_drop_f = @ir.hot_region_get(func, body, 8)
  let later_drop_g = @ir.hot_region_get(func, body, 9)
  let selected_get = @ir.hot_region_get(func, body, 10)
  match @ir.hot_node_get(func, earlier_drop_a).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected first earlier effectful sibling to be dropped first")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, earlier_drop_a, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected first earlier tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, earlier_drop_b).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected second earlier effectful sibling to be dropped second")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, earlier_drop_b, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected second earlier tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, selected_set).op {
    @ir.HotOp::LocalSet => ()
    _ =>
      fail("expected selected trapping lane to be stored before later siblings")
  }
  let stored_load = @ir.hot_child_get(func, selected_set, 0)
  match @ir.hot_node_exact_instr(func, stored_load) {
    Some(@lib.Instruction::I32Load(_)) => ()
    _ => fail("expected localized selected lane to keep exact i32.load")
  }
  match @ir.hot_node_get(func, later_drop_a).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected first later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_a, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected first later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_b).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected second later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_b, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected second later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_c).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected third later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_c, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected third later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_d).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected fourth later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_d, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected fourth later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_e).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected fifth later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_e, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected fifth later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_f).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected sixth later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_f, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected sixth later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_g).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected seventh later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_g, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected seventh later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, selected_get).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected selected trapping lane to reload after later siblings")
  }
  @debug.assert_eq(
    @ir.hot_node_get(func, selected_get).imm0,
    @ir.hot_node_get(func, selected_set).imm0,
  )
}

///|
test "optimize-instructions preserves selected trapping tuple.extract lane with two earlier and eight later siblings" {
  // OI-M selected-lane/effect-order coverage: Binaryen `version_130`
  // `--optimize-instructions` drops two earlier siblings, localizes the selected
  // trapping `i32.load`, drops eight later siblings, and reloads the selected lane
  // in `.tmp/oi-m-tuple-selected-trapping-two-earlier-eight-later-probe.wat`.
  // Starshine's direct-HOT localizer should preserve the same effect/trap order.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let earlier_call_a = @ir.hot_build_call(func, 0, [@lib.ValType::i64()], [])
  let earlier_call_b = @ir.hot_build_call(func, 1, [@lib.ValType::i64()], [])
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
  let selected_load = @ir.hot_build_load(
    func,
    @lib.ValType::i32(),
    memarg,
    @ir.hot_build_local_get(func, 0),
  )
  @ir.hot_node_exact_instr_set(
    func,
    selected_load,
    @lib.Instruction::i32_load(memarg),
  )
  let later_call_a = @ir.hot_build_call(func, 2, [@lib.ValType::i32()], [])
  let later_call_b = @ir.hot_build_call(func, 3, [@lib.ValType::i32()], [])
  let later_call_c = @ir.hot_build_call(func, 4, [@lib.ValType::i32()], [])
  let later_call_d = @ir.hot_build_call(func, 5, [@lib.ValType::i32()], [])
  let later_call_e = @ir.hot_build_call(func, 6, [@lib.ValType::i32()], [])
  let later_call_f = @ir.hot_build_call(func, 7, [@lib.ValType::i32()], [])
  let later_call_g = @ir.hot_build_call(func, 8, [@lib.ValType::i32()], [])
  let later_call_h = @ir.hot_build_call(func, 9, [@lib.ValType::i32()], [])
  let tuple = @ir.hot_build_tuple_make(
    func,
    [
      @lib.ValType::i64(),
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ],
    [
      earlier_call_a, earlier_call_b, selected_load, later_call_a, later_call_b,
      later_call_c, later_call_d, later_call_e, later_call_f, later_call_g, later_call_h,
    ],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 2)
  @ir.hot_root_append(func, extract)

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
        "expected selected trapping tuple two-earlier/eight-later-sibling localization success, got \{err}",
      )
  }

  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block => ()
    _ =>
      fail(
        "expected selected trapping two-earlier/eight-later-sibling tuple.extract to become a block",
      )
  }
  let body = @ir.hot_region_body_ref(func, root)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 12)
  let earlier_drop_a = @ir.hot_region_get(func, body, 0)
  let earlier_drop_b = @ir.hot_region_get(func, body, 1)
  let selected_set = @ir.hot_region_get(func, body, 2)
  let later_drop_a = @ir.hot_region_get(func, body, 3)
  let later_drop_b = @ir.hot_region_get(func, body, 4)
  let later_drop_c = @ir.hot_region_get(func, body, 5)
  let later_drop_d = @ir.hot_region_get(func, body, 6)
  let later_drop_e = @ir.hot_region_get(func, body, 7)
  let later_drop_f = @ir.hot_region_get(func, body, 8)
  let later_drop_g = @ir.hot_region_get(func, body, 9)
  let later_drop_h = @ir.hot_region_get(func, body, 10)
  let selected_get = @ir.hot_region_get(func, body, 11)
  match @ir.hot_node_get(func, earlier_drop_a).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected first earlier effectful sibling to be dropped first")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, earlier_drop_a, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected first earlier tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, earlier_drop_b).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected second earlier effectful sibling to be dropped second")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, earlier_drop_b, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected second earlier tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, selected_set).op {
    @ir.HotOp::LocalSet => ()
    _ =>
      fail("expected selected trapping lane to be stored before later siblings")
  }
  let stored_load = @ir.hot_child_get(func, selected_set, 0)
  match @ir.hot_node_exact_instr(func, stored_load) {
    Some(@lib.Instruction::I32Load(_)) => ()
    _ => fail("expected localized selected lane to keep exact i32.load")
  }
  match @ir.hot_node_get(func, later_drop_a).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected first later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_a, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected first later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_b).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected second later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_b, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected second later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_c).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected third later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_c, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected third later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_d).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected fourth later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_d, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected fourth later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_e).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected fifth later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_e, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected fifth later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_f).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected sixth later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_f, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected sixth later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_g).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected seventh later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_g, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected seventh later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, later_drop_h).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected eighth later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop_h, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected eighth later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, selected_get).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected selected trapping lane to reload after later siblings")
  }
  @debug.assert_eq(
    @ir.hot_node_get(func, selected_get).imm0,
    @ir.hot_node_get(func, selected_set).imm0,
  )
}

///|
test "optimize-instructions preserves selected trapping tuple.extract lane with earlier and later siblings" {
  // OI-M selected-lane/effect-order coverage: Binaryen `version_130`
  // `--optimize-instructions` drops the earlier sibling, localizes the selected
  // trapping `i32.load`, drops the later sibling, and reloads the selected lane
  // in `.tmp/oi-m-tuple-selected-trapping-earlier-later-probe.wat`. Starshine's
  // direct-HOT localizer should preserve the same effect/trap order.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let earlier_call = @ir.hot_build_call(func, 0, [@lib.ValType::i64()], [])
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
  let selected_load = @ir.hot_build_load(
    func,
    @lib.ValType::i32(),
    memarg,
    @ir.hot_build_local_get(func, 0),
  )
  @ir.hot_node_exact_instr_set(
    func,
    selected_load,
    @lib.Instruction::i32_load(memarg),
  )
  let later_call = @ir.hot_build_call(func, 1, [@lib.ValType::i32()], [])
  let tuple = @ir.hot_build_tuple_make(
    func,
    [@lib.ValType::i64(), @lib.ValType::i32(), @lib.ValType::i32()],
    [earlier_call, selected_load, later_call],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 1)
  @ir.hot_root_append(func, extract)

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
        "expected selected trapping tuple earlier/later-sibling localization success, got \{err}",
      )
  }

  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block => ()
    _ =>
      fail(
        "expected selected trapping earlier/later-sibling tuple.extract to become a block",
      )
  }
  let body = @ir.hot_region_body_ref(func, root)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 4)
  let earlier_drop = @ir.hot_region_get(func, body, 0)
  let selected_set = @ir.hot_region_get(func, body, 1)
  let later_drop = @ir.hot_region_get(func, body, 2)
  let selected_get = @ir.hot_region_get(func, body, 3)
  match @ir.hot_node_get(func, earlier_drop).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected earlier effectful sibling to be dropped first")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, earlier_drop, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected earlier tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, selected_set).op {
    @ir.HotOp::LocalSet => ()
    _ =>
      fail("expected selected trapping lane to be stored before later sibling")
  }
  let stored_load = @ir.hot_child_get(func, selected_set, 0)
  match @ir.hot_node_exact_instr(func, stored_load) {
    Some(@lib.Instruction::I32Load(_)) => ()
    _ => fail("expected localized selected lane to keep exact i32.load")
  }
  match @ir.hot_node_get(func, later_drop).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail("expected later effectful sibling to be dropped after selected load")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop, 0)).op {
    @ir.HotOp::Call => ()
    _ => fail("expected later tuple sibling call to stay available")
  }
  match @ir.hot_node_get(func, selected_get).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected selected trapping lane to reload after later sibling")
  }
  @debug.assert_eq(
    @ir.hot_node_get(func, selected_get).imm0,
    @ir.hot_node_get(func, selected_set).imm0,
  )
}

///|
test "optimize-instructions preserves selected trapping tuple.extract lane with two later siblings" {
  // OI-M selected-lane/effect-order coverage: Binaryen `version_130`
  // `--optimize-instructions` keeps an earlier effect, a selected trapping load,
  // and two later effects in order via tuple scratch in
  // `.tmp/oi-m-tuple-selected-trapping-two-later-probe.wat`. Starshine's
  // direct-HOT localizer may use a smaller block, but it must not move either
  // later sibling before the selected load or reload the selected lane too early.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let earlier_call = @ir.hot_build_call(func, 0, [@lib.ValType::i64()], [])
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
  let selected_load = @ir.hot_build_load(
    func,
    @lib.ValType::i32(),
    memarg,
    @ir.hot_build_local_get(func, 0),
  )
  @ir.hot_node_exact_instr_set(
    func,
    selected_load,
    @lib.Instruction::i32_load(memarg),
  )
  let later_call_a = @ir.hot_build_call(func, 1, [@lib.ValType::i32()], [])
  let later_call_b = @ir.hot_build_call(func, 2, [@lib.ValType::i32()], [])
  let tuple = @ir.hot_build_tuple_make(
    func,
    [
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
      @lib.ValType::i32(),
    ],
    [earlier_call, selected_load, later_call_a, later_call_b],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 1)
  @ir.hot_root_append(func, extract)

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
        "expected selected trapping tuple two-later-sibling localization success, got \{err}",
      )
  }

  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block => ()
    _ =>
      fail(
        "expected selected trapping two-later-sibling tuple.extract to become a block",
      )
  }
  let body = @ir.hot_region_body_ref(func, root)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 5)
  let earlier_drop = @ir.hot_region_get(func, body, 0)
  let selected_set = @ir.hot_region_get(func, body, 1)
  let later_drop_a = @ir.hot_region_get(func, body, 2)
  let later_drop_b = @ir.hot_region_get(func, body, 3)
  let selected_get = @ir.hot_region_get(func, body, 4)
  match @ir.hot_node_get(func, earlier_drop).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected earlier effectful sibling to be dropped first")
  }
  match @ir.hot_node_get(func, selected_set).op {
    @ir.HotOp::LocalSet => ()
    _ =>
      fail("expected selected trapping lane to be stored before later siblings")
  }
  let stored_load = @ir.hot_child_get(func, selected_set, 0)
  match @ir.hot_node_exact_instr(func, stored_load) {
    Some(@lib.Instruction::I32Load(_)) => ()
    _ => fail("expected localized selected lane to keep exact i32.load")
  }
  match @ir.hot_node_get(func, later_drop_a).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected first later effectful sibling to be dropped after selected load",
      )
  }
  match @ir.hot_node_get(func, later_drop_b).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected second later effectful sibling to be dropped after first later sibling",
      )
  }
  match @ir.hot_node_get(func, selected_get).op {
    @ir.HotOp::LocalGet => ()
    _ =>
      fail(
        "expected selected trapping lane to reload after both later siblings",
      )
  }
  @debug.assert_eq(
    @ir.hot_node_get(func, selected_get).imm0,
    @ir.hot_node_get(func, selected_set).imm0,
  )
}

///|
test "optimize-instructions localizes tuple.extract of tuple.make with effectful siblings" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i64(),
    ]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let tuple = @ir.hot_build_tuple_make(
    func,
    [@lib.ValType::i32(), @lib.ValType::i64()],
    [
      @ir.hot_build_local_get(func, 0),
      @ir.hot_build_local_tee(
        func,
        1,
        @ir.hot_build_const_i64(func, @lib.I64(9L)),
      ),
    ],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 0)
  @ir.hot_root_append(func, extract)

  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected tuple.extract localization success, got \{err}")
  }

  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block => ()
    _ => fail("expected effectful sibling tuple.extract to become a block")
  }
  let body = @ir.hot_region_body_ref(func, root)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 3)
  let selected_set = @ir.hot_region_get(func, body, 0)
  let sibling_drop = @ir.hot_region_get(func, body, 1)
  let selected_get = @ir.hot_region_get(func, body, 2)
  match @ir.hot_node_get(func, selected_set).op {
    @ir.HotOp::LocalSet => ()
    _ => fail("expected selected tuple child to be localized before sibling")
  }
  match @ir.hot_node_get(func, sibling_drop).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected non-selected effectful sibling to be dropped")
  }
  let dropped = @ir.hot_child_get(func, sibling_drop, 0)
  match @ir.hot_node_get(func, dropped).op {
    @ir.HotOp::LocalTee => ()
    _ => fail("expected dropped sibling to preserve local.tee effect")
  }
  match @ir.hot_node_get(func, selected_get).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected localized selected tuple child to be reloaded")
  }
  @debug.assert_eq(
    @ir.hot_node_get(func, selected_get).imm0,
    @ir.hot_node_get(func, selected_set).imm0,
  )
}

///|
test "optimize-instructions intentionally keeps multi-use tuple.make boundary" {
  // Boundary-only OI-M classification: Binaryen `version_130`
  // `--optimize-instructions` keeps tuple extractions through a local-carried
  // multi-use tuple (`.tmp/oi-m-tuple-multiuse-probe.wat`). Starshine's direct
  // tuple.extract(tuple.make(...)) forwarding remains one-use-only, and this
  // direct-HOT fixture locks the same multi-use proof boundary rather than
  // claiming broader tuple reconstruction parity.
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let tuple = @ir.hot_build_tuple_make(
    func,
    [@lib.ValType::i32(), @lib.ValType::i64()],
    [
      @ir.hot_build_const_i32(func, @lib.I32(1)),
      @ir.hot_build_const_i64(func, @lib.I64(2L)),
    ],
  )
  let ignored = @ir.hot_build_tuple_extract(func, @lib.ValType::i64(), tuple, 1)
  let selected = @ir.hot_build_tuple_extract(
    func,
    @lib.ValType::i32(),
    tuple,
    0,
  )
  @ir.hot_root_append(func, @ir.hot_build_drop(func, ignored))
  @ir.hot_root_append(func, selected)

  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected multi-use tuple boundary success, got \{err}")
  }

  let result = @ir.hot_root_get(func, 1)
  match @ir.hot_node_get(func, result).op {
    @ir.HotOp::TupleExtract => ()
    _ => fail("expected multi-use tuple.extract to stay unchanged")
  }
  let result_tuple = @ir.hot_child_get(func, result, 0)
  @debug.assert_eq(result_tuple, tuple)
  match @ir.hot_node_get(func, tuple).op {
    @ir.HotOp::TupleMake => ()
    _ => fail("expected multi-use tuple.make to stay available")
  }
}

///|
test "optimize-instructions intentionally keeps tuple.extract with multi-result sibling boundary" {
  // Boundary-only OI-M classification: Binaryen `version_130`
  // `--optimize-instructions` localizes the probed multi-result sibling
  // through tuple scratch plus scalar drops (`.tmp/oi-m-tuple-multiresult-sibling-probe.wat`).
  // Starshine's direct tuple.extract localizer currently proves only
  // single-result effectful non-selected siblings, so this fixture keeps the
  // direct-HOT tuple spelling explicit instead of hiding tuple-scratch parity.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let selected = @ir.hot_build_local_get(func, 0)
  let sibling = @ir.hot_build_call(
    func,
    0,
    [@lib.ValType::i64(), @lib.ValType::i32()],
    [],
  )
  let tuple = @ir.hot_build_tuple_make(
    func,
    [@lib.ValType::i32(), @lib.ValType::i64(), @lib.ValType::i32()],
    [selected, sibling],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 0)
  @ir.hot_root_append(func, extract)

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
      fail("expected multi-result tuple sibling boundary success, got \{err}")
  }

  let result = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, result).op {
    @ir.HotOp::TupleExtract => ()
    _ => fail("expected multi-result sibling tuple.extract to stay unchanged")
  }
  @debug.assert_eq(@ir.hot_child_get(func, result, 0), tuple)
  match @ir.hot_node_get(func, tuple).op {
    @ir.HotOp::TupleMake => ()
    _ => fail("expected multi-result sibling tuple.make to stay available")
  }
  match @ir.hot_node_get(func, sibling).op {
    @ir.HotOp::Call => ()
    _ => fail("expected multi-result effectful sibling call to stay available")
  }
}

///|
test "optimize-instructions intentionally keeps tuple.extract with earlier multi-result sibling boundary" {
  // Boundary-only OI-M classification: Binaryen `version_130`
  // `--optimize-instructions` localizes the earlier multi-result sibling through
  // tuple scratch before returning the selected scalar lane
  // (`.tmp/oi-m-tuple-multiresult-earlier-sibling-probe.wat`). Starshine's
  // direct tuple.extract localizer currently proves only single-result effectful
  // non-selected siblings, so this fixture keeps the direct-HOT tuple spelling
  // explicit instead of claiming tuple-scratch parity.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let sibling = @ir.hot_build_call(
    func,
    0,
    [@lib.ValType::i64(), @lib.ValType::i32()],
    [],
  )
  let selected = @ir.hot_build_local_get(func, 0)
  let tuple = @ir.hot_build_tuple_make(
    func,
    [@lib.ValType::i64(), @lib.ValType::i32(), @lib.ValType::i32()],
    [sibling, selected],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 2)
  @ir.hot_root_append(func, extract)

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
        "expected earlier multi-result tuple sibling boundary success, got \{err}",
      )
  }

  let result = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, result).op {
    @ir.HotOp::TupleExtract => ()
    _ =>
      fail(
        "expected earlier multi-result sibling tuple.extract to stay unchanged",
      )
  }
  @debug.assert_eq(@ir.hot_child_get(func, result, 0), tuple)
  @debug.assert_eq(@ir.hot_node_get(func, result).imm0, 2)
  match @ir.hot_node_get(func, tuple).op {
    @ir.HotOp::TupleMake => ()
    _ =>
      fail("expected earlier multi-result sibling tuple.make to stay available")
  }
  match @ir.hot_node_get(func, sibling).op {
    @ir.HotOp::Call => ()
    _ => fail("expected earlier multi-result sibling call to stay available")
  }
}

///|
test "optimize-instructions intentionally keeps tuple.extract with multi-result selected lane boundary" {
  // Boundary-only OI-M classification: Binaryen `version_130`
  // `--optimize-instructions` localizes selected values produced by a
  // multi-result tuple child through tuple scratch and scalar temps
  // (`.tmp/oi-m-tuple-multiresult-selected-probe.wat`). Starshine's direct
  // tuple.extract localizer currently proves only single-result selected
  // children, so this fixture keeps the direct-HOT tuple spelling explicit.
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i64()),
  )
  let selected = @ir.hot_build_call(
    func,
    0,
    [@lib.ValType::i64(), @lib.ValType::i32()],
    [],
  )
  let tuple = @ir.hot_build_tuple_make(
    func,
    [@lib.ValType::i64(), @lib.ValType::i32(), @lib.ValType::i32()],
    [selected, @ir.hot_build_const_i32(func, @lib.I32(9))],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i64(), tuple, 0)
  @ir.hot_root_append(func, extract)

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
      fail("expected multi-result selected tuple boundary success, got \{err}")
  }

  let result = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, result).op {
    @ir.HotOp::TupleExtract => ()
    _ => fail("expected multi-result selected tuple.extract to stay unchanged")
  }
  @debug.assert_eq(@ir.hot_child_get(func, result, 0), tuple)
  match @ir.hot_node_get(func, tuple).op {
    @ir.HotOp::TupleMake => ()
    _ => fail("expected multi-result selected tuple.make to stay available")
  }
  match @ir.hot_node_get(func, selected).op {
    @ir.HotOp::Call => ()
    _ => fail("expected multi-result selected call to stay available")
  }
}

///|
test "optimize-instructions intentionally keeps tuple.extract with multi-result selected second lane boundary" {
  // Boundary-only OI-M classification: Binaryen `version_130`
  // `--optimize-instructions` localizes the second scalar result selected from
  // a multi-result tuple child through tuple scratch plus scalar temps
  // (`.tmp/oi-m-tuple-multiresult-selected-second-probe.wat`). Starshine's
  // direct tuple.extract localizer currently proves only single-result selected
  // children, so this fixture locks the second-lane variant of the same
  // tuple-scratch boundary.
  let func = @ir.HotFunc::new()
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let selected = @ir.hot_build_call(
    func,
    0,
    [@lib.ValType::i64(), @lib.ValType::i32()],
    [],
  )
  let tuple = @ir.hot_build_tuple_make(
    func,
    [@lib.ValType::i64(), @lib.ValType::i32(), @lib.ValType::i32()],
    [selected, @ir.hot_build_const_i32(func, @lib.I32(9))],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 1)
  @ir.hot_root_append(func, extract)

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
        "expected multi-result selected second-lane tuple boundary success, got \{err}",
      )
  }

  let result = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, result).op {
    @ir.HotOp::TupleExtract => ()
    _ =>
      fail(
        "expected multi-result selected second-lane tuple.extract to stay unchanged",
      )
  }
  @debug.assert_eq(@ir.hot_child_get(func, result, 0), tuple)
  @debug.assert_eq(@ir.hot_node_get(func, result).imm0, 1)
  match @ir.hot_node_get(func, tuple).op {
    @ir.HotOp::TupleMake => ()
    _ =>
      fail(
        "expected multi-result selected second-lane tuple.make to stay available",
      )
  }
  match @ir.hot_node_get(func, selected).op {
    @ir.HotOp::Call => ()
    _ =>
      fail("expected multi-result selected second-lane call to stay available")
  }
}

///|
test "optimize-instructions preserves earlier and later tuple.extract sibling effects" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i64(),
      @lib.ValType::i64(),
    ]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let tuple = @ir.hot_build_tuple_make(
    func,
    [
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i64(),
      @lib.ValType::i64(),
    ],
    [
      @ir.hot_build_local_tee(
        func,
        1,
        @ir.hot_build_const_i64(func, @lib.I64(9L)),
      ),
      @ir.hot_build_local_get(func, 0),
      @ir.hot_build_const_i64(func, @lib.I64(11L)),
      @ir.hot_build_local_tee(
        func,
        2,
        @ir.hot_build_const_i64(func, @lib.I64(10L)),
      ),
    ],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 1)
  @ir.hot_root_append(func, extract)

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
        "expected tuple.extract multi-sibling localization success, got \{err}",
      )
  }

  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block => ()
    _ =>
      fail(
        "expected tuple.extract with earlier and later effects to become a block",
      )
  }
  let body = @ir.hot_region_body_ref(func, root)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 4)
  let earlier_drop = @ir.hot_region_get(func, body, 0)
  let selected_set = @ir.hot_region_get(func, body, 1)
  let later_drop = @ir.hot_region_get(func, body, 2)
  let selected_get = @ir.hot_region_get(func, body, 3)
  match @ir.hot_node_get(func, earlier_drop).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected earlier effectful sibling to be dropped before selected lane",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, earlier_drop, 0)).op {
    @ir.HotOp::LocalTee => ()
    _ => fail("expected earlier dropped sibling to preserve local.tee effect")
  }
  match @ir.hot_node_get(func, selected_set).op {
    @ir.HotOp::LocalSet => ()
    _ => fail("expected selected lane to localize before later effect")
  }
  match @ir.hot_node_get(func, later_drop).op {
    @ir.HotOp::Drop => ()
    _ =>
      fail(
        "expected later effectful sibling to be dropped after selected local.set",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop, 0)).op {
    @ir.HotOp::LocalTee => ()
    _ => fail("expected later dropped sibling to preserve local.tee effect")
  }
  match @ir.hot_node_get(func, selected_get).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected selected lane to reload after later effect")
  }
  @debug.assert_eq(
    @ir.hot_node_get(func, selected_get).imm0,
    @ir.hot_node_get(func, selected_set).imm0,
  )
}

///|
test "optimize-instructions preserves trapping tuple.extract sibling loads" {
  // OI-M trap-preservation coverage: Binaryen `version_130`
  // `--optimize-instructions` drops trapping load siblings while selecting the
  // middle scalar lane (`.tmp/oi-m-tuple-trapping-sibling-probe.wat`). Starshine
  // must treat those load siblings as non-pure and keep them as dropped effects,
  // not silently omit them as pure tuple debris.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let memarg = @lib.MemArg::new(@lib.U32(0), None, @lib.U64(0))
  let earlier_load = @ir.hot_build_load(
    func,
    @lib.ValType::i32(),
    memarg,
    @ir.hot_build_local_get(func, 0),
  )
  @ir.hot_node_exact_instr_set(
    func,
    earlier_load,
    @lib.Instruction::i32_load(memarg),
  )
  let later_addr = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    @ir.hot_build_local_get(func, 0),
    @ir.hot_build_const_i32(func, @lib.I32(4)),
  )
  @ir.hot_node_exact_instr_set(func, later_addr, @lib.Instruction::i32_add())
  let later_load = @ir.hot_build_load(
    func,
    @lib.ValType::i32(),
    memarg,
    later_addr,
  )
  @ir.hot_node_exact_instr_set(
    func,
    later_load,
    @lib.Instruction::i32_load(memarg),
  )
  let tuple = @ir.hot_build_tuple_make(
    func,
    [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
    [earlier_load, @ir.hot_build_local_get(func, 1), later_load],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 1)
  @ir.hot_root_append(func, extract)

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
      fail("expected trapping tuple sibling localization success, got \{err}")
  }

  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block => ()
    _ => fail("expected trapping tuple sibling localization to become a block")
  }
  let body = @ir.hot_region_body_ref(func, root)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 4)
  let earlier_drop = @ir.hot_region_get(func, body, 0)
  let selected_set = @ir.hot_region_get(func, body, 1)
  let later_drop = @ir.hot_region_get(func, body, 2)
  let selected_get = @ir.hot_region_get(func, body, 3)
  match @ir.hot_node_get(func, earlier_drop).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected earlier trapping sibling to be dropped")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, earlier_drop, 0)).op {
    @ir.HotOp::Load => ()
    _ => fail("expected earlier dropped sibling to remain a load")
  }
  match @ir.hot_node_get(func, selected_set).op {
    @ir.HotOp::LocalSet => ()
    _ =>
      fail("expected selected lane to localize before later trapping sibling")
  }
  match @ir.hot_node_get(func, later_drop).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected later trapping sibling to be dropped")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, later_drop, 0)).op {
    @ir.HotOp::Load => ()
    _ => fail("expected later dropped sibling to remain a load")
  }
  match @ir.hot_node_get(func, selected_get).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected selected lane to reload after later trapping sibling")
  }
  @debug.assert_eq(
    @ir.hot_node_get(func, selected_get).imm0,
    @ir.hot_node_get(func, selected_set).imm0,
  )
}

///|
test "optimize-instructions tuple.extract localization survives simplify-locals-nostructure neighbor" {
  // Boundary/status OI-M neighbor coverage: Binaryen `version_130`
  // `--optimize-instructions --simplify-locals-nostructure` keeps the probed
  // effect-preserving tuple.extract localization as temp-local traffic around
  // the non-selected effect (`.tmp/oi-m-tuple-probe.wat`). Starshine's direct
  // HOT neighbor replay should not collapse the temp across the intervening
  // effect or claim broader tuple/simplify-locals parity.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i64(),
    ]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let tuple = @ir.hot_build_tuple_make(
    func,
    [@lib.ValType::i32(), @lib.ValType::i64()],
    [
      @ir.hot_build_local_get(func, 0),
      @ir.hot_build_local_tee(
        func,
        1,
        @ir.hot_build_const_i64(func, @lib.I64(9L)),
      ),
    ],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 0)
  @ir.hot_root_append(func, extract)

  let oi_ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(oi_ctx, func) {
    Ok(_) => ()
    Err(err) => fail("expected tuple.extract OI success, got \{err}")
  }
  let sln_ctx = HotPassContext::new(
    simplify_locals_nostructure_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(sln_ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected tuple.extract simplify-locals-nostructure neighbor success, got \{err}",
      )
  }

  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block => ()
    _ => fail("expected tuple localization to remain effect-preserving block")
  }
  let body = @ir.hot_region_body_ref(func, root)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 3)
  let selected_set = @ir.hot_region_get(func, body, 0)
  let sibling_drop = @ir.hot_region_get(func, body, 1)
  let selected_get = @ir.hot_region_get(func, body, 2)
  match @ir.hot_node_get(func, selected_set).op {
    @ir.HotOp::LocalSet => ()
    _ => fail("expected selected lane temp local.set to survive neighbor")
  }
  match @ir.hot_node_get(func, sibling_drop).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected non-selected effect drop to survive neighbor")
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, sibling_drop, 0)).op {
    @ir.HotOp::LocalTee => ()
    _ => fail("expected non-selected local.tee effect to survive neighbor")
  }
  match @ir.hot_node_get(func, selected_get).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected selected lane temp local.get to survive neighbor")
  }
  @debug.assert_eq(
    @ir.hot_node_get(func, selected_get).imm0,
    @ir.hot_node_get(func, selected_set).imm0,
  )
}

///|
test "optimize-instructions earlier and later tuple.extract localization survives simplify-locals-nostructure neighbor" {
  // Status-only OI-M neighbor coverage: this direct-HOT fixture extends the
  // covered single-result tuple.extract localization to the earlier+later
  // effectful sibling subset under `simplify-locals-nostructure`. Public WAT
  // tuple syntax is not accepted by Starshine's local WAT parser yet, so this is
  // not claimed as public text-pipeline parity.
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i64(),
      @lib.ValType::i64(),
    ]),
  )
  @ir.hot_body_result_type_set(
    func,
    @ir.hot_type_intern_value(func, @lib.ValType::i32()),
  )
  let tuple = @ir.hot_build_tuple_make(
    func,
    [
      @lib.ValType::i64(),
      @lib.ValType::i32(),
      @lib.ValType::i64(),
      @lib.ValType::i64(),
    ],
    [
      @ir.hot_build_local_tee(
        func,
        1,
        @ir.hot_build_const_i64(func, @lib.I64(9L)),
      ),
      @ir.hot_build_local_get(func, 0),
      @ir.hot_build_const_i64(func, @lib.I64(11L)),
      @ir.hot_build_local_tee(
        func,
        2,
        @ir.hot_build_const_i64(func, @lib.I64(10L)),
      ),
    ],
  )
  let extract = @ir.hot_build_tuple_extract(func, @lib.ValType::i32(), tuple, 1)
  @ir.hot_root_append(func, extract)

  let oi_ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(oi_ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected earlier/later tuple.extract OI success, got \{err}")
  }
  let sln_ctx = HotPassContext::new(
    simplify_locals_nostructure_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(sln_ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected earlier/later tuple.extract simplify-locals-nostructure neighbor success, got \{err}",
      )
  }

  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block => ()
    _ => fail("expected earlier/later tuple localization to remain a block")
  }
  let body = @ir.hot_region_body_ref(func, root)
  @debug.assert_eq(@ir.hot_region_root_count(func, body), 4)
  let earlier_drop = @ir.hot_region_get(func, body, 0)
  let selected_set = @ir.hot_region_get(func, body, 1)
  let later_drop = @ir.hot_region_get(func, body, 2)
  let selected_get = @ir.hot_region_get(func, body, 3)
  match @ir.hot_node_get(func, earlier_drop).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected earlier sibling drop to survive neighbor")
  }
  match @ir.hot_node_get(func, selected_set).op {
    @ir.HotOp::LocalSet => ()
    _ => fail("expected selected temp set to survive neighbor")
  }
  match @ir.hot_node_get(func, later_drop).op {
    @ir.HotOp::Drop => ()
    _ => fail("expected later sibling drop to survive neighbor")
  }
  match @ir.hot_node_get(func, selected_get).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected selected temp reload to survive neighbor")
  }
  @debug.assert_eq(
    @ir.hot_node_get(func, selected_get).imm0,
    @ir.hot_node_get(func, selected_set).imm0,
  )
}

///|
test "optimize-instructions intentionally keeps public multivalue block through full simplify-locals boundary" {
  // Boundary-only OI-M neighbor coverage: Binaryen `version_130`
  // `--optimize-instructions --simplify-locals` localizes the probed multivalue
  // block through tuple scratch plus scalar-local traffic around the
  // non-selected effect (`.tmp/oi-m-tuple-full-simplify-neighbor-probe.wat`).
  // Starshine's public WAT pipeline keeps the multivalue block/drop spelling;
  // a direct-HOT replay of the OI-localized tuple block is a separate verifier
  // boundary (`InvalidChildRef`). Do not report this as full simplify-locals
  // neighbor parity until one of those paths is fixed.
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func $side (result i64)
        #|    i64.const 9)
        #|  (func (param $x i32) (result i32)
        #|    (block (result i32 i64)
        #|      local.get $x
        #|      call $side)
        #|    drop))
        #|,
      ),
      ["optimize-instructions", "simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected public multivalue full simplify-locals boundary success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("block"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_false(pretty.contains("local.set"), msg=pretty)
}

///|
test "optimize-instructions intentionally keeps public multivalue block through tuple-optimization boundary" {
  // Boundary-only OI-M neighbor coverage: Binaryen `version_130`
  // `--optimize-instructions --tuple-optimization` localizes the probed
  // multivalue block through tuple scratch plus scalar-local traffic around the
  // non-selected effect (`.tmp/oi-m-tuple-optimization-neighbor-probe.wat`).
  // Starshine's public WAT pipeline keeps the multivalue block/drop spelling;
  // do not report this as tuple-optimization neighbor parity until tuple-scratch
  // reconstruction/localization is implemented locally.
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func $side (result i64)
        #|    i64.const 9)
        #|  (func (param $x i32) (result i32)
        #|    (block (result i32 i64)
        #|      local.get $x
        #|      call $side)
        #|    drop))
        #|,
      ),
      ["optimize-instructions", "tuple-optimization"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected public multivalue tuple-optimization boundary success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("block"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_false(pretty.contains("local.set"), msg=pretty)
}

///|
test "optimize-instructions folds array.len of pure array.new_fixed length" {
  let array_type = @lib.TypeIdx::new(0U)
  let effect_type = @lib.TypeIdx::new(1U)
  let result_type = @lib.TypeIdx::new(2U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
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
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([effect_type, result_type, result_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(99))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::array_new_fixed(array_type, @lib.U32(2U)),
            @lib.Instruction::array_len(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::array_new_fixed(array_type, @lib.U32(2U)),
            @lib.Instruction::array_len(),
          ]),
        ),
      ]),
    ),
  )
  let pure = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let effectful = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_false(pure.contains("array.len"), msg=pure)
  assert_false(pure.contains("array.new_fixed"), msg=pure)
  assert_true(pure.contains("I32(2)"), msg=pure)
  // Boundary-only half of this OI-K slice: Binaryen currently leaves the
  // effectful element form intact, and Starshine must not drop element effects.
  assert_true(effectful.contains("array.len"), msg=effectful)
  assert_true(effectful.contains("array.new_fixed"), msg=effectful)
  assert_true(effectful.contains("call (Func 0)"), msg=effectful)
}

///|
test "optimize-instructions folds array.len of constant-size array.new_default" {
  let array_type = @lib.TypeIdx::new(0U)
  let result_type = @lib.TypeIdx::new(1U)
  let param_result_type = @lib.TypeIdx::new(2U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
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
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([
        result_type, param_result_type, result_type, result_type,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::array_new_default(array_type),
            @lib.Instruction::array_len(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::array_new_default(array_type),
            @lib.Instruction::array_len(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(-1)),
            @lib.Instruction::array_new_default(array_type),
            @lib.Instruction::array_len(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(2147483647)),
            @lib.Instruction::array_new_default(array_type),
            @lib.Instruction::array_len(),
          ]),
        ),
      ]),
    ),
  )
  let constant_len = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let dynamic_len = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let negative_len = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let huge_len = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_false(constant_len.contains("array.len"), msg=constant_len)
  assert_false(constant_len.contains("array.new_default"), msg=constant_len)
  assert_true(constant_len.contains("I32(3)"), msg=constant_len)
  // Boundary-only half of this OI-K slice: Binaryen's O4z-style oracle keeps
  // dynamic-length default arrays because removing allocation could drop the
  // allocation-size trap.
  assert_true(dynamic_len.contains("array.len"), msg=dynamic_len)
  assert_true(dynamic_len.contains("array.new_default"), msg=dynamic_len)
  // Boundary-only half of this OI-K slice: Binaryen also keeps negative
  // i32.const lengths because the huge unsigned allocation should still trap.
  assert_true(negative_len.contains("array.len"), msg=negative_len)
  assert_true(negative_len.contains("array.new_default"), msg=negative_len)
  // Boundary-only half of this OI-K slice: Binaryen keeps huge non-negative
  // lengths past the O4z-observed allocation limit for the same trap reason.
  assert_true(huge_len.contains("array.len"), msg=huge_len)
  assert_true(huge_len.contains("array.new_default"), msg=huge_len)
}

///|
test "optimize-instructions folds array.len of constant-value constant-size array.new" {
  let array_type = @lib.TypeIdx::new(0U)
  let result_type = @lib.TypeIdx::new(1U)
  let param_result_type = @lib.TypeIdx::new(2U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
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
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([
        result_type, result_type, param_result_type, result_type, result_type, result_type,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(9))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::array_new(array_type),
            @lib.Instruction::array_len(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::array_new(array_type),
            @lib.Instruction::array_len(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::array_new(array_type),
            @lib.Instruction::array_len(),
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
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::i32_const(@lib.I32(2147483647)),
            @lib.Instruction::array_new(array_type),
            @lib.Instruction::array_len(),
          ]),
        ),
      ]),
    ),
  )
  let constant_value = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let local_value = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let effectful_value = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  let negative_len = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  let huge_len = optimized.pretty_print_func(@lib.FuncIdx::new(5U))
  assert_false(constant_value.contains("array.len"), msg=constant_value)
  assert_false(constant_value.contains("array.new"), msg=constant_value)
  assert_true(constant_value.contains("I32(3)"), msg=constant_value)
  // Boundary-only half of this OI-K slice: Binaryen's O4z-style oracle keeps
  // nonconstant repeated values, even pure local.get values, so Starshine keeps
  // them until a broader source-backed proof justifies dropping value evaluation.
  assert_true(local_value.contains("array.len"), msg=local_value)
  assert_true(local_value.contains("array.new"), msg=local_value)
  // Boundary-only half of this OI-K slice: effectful repeated values must not be
  // dropped while removing the allocation.
  assert_true(effectful_value.contains("array.len"), msg=effectful_value)
  assert_true(effectful_value.contains("array.new"), msg=effectful_value)
  assert_true(effectful_value.contains("call (Func 0)"), msg=effectful_value)
  // Boundary-only half of this OI-K slice: trap-preserving length limits mirror
  // the array.new_default length slice.
  assert_true(negative_len.contains("array.len"), msg=negative_len)
  assert_true(negative_len.contains("array.new"), msg=negative_len)
  assert_true(huge_len.contains("array.len"), msg=huge_len)
  assert_true(huge_len.contains("array.new"), msg=huge_len)
}

///|
test "optimize-instructions folds array.get of pure array.new_fixed elements" {
  let array_type = @lib.TypeIdx::new(0U)
  let effect_type = @lib.TypeIdx::new(1U)
  let result_type = @lib.TypeIdx::new(2U)
  let indexed_type = @lib.TypeIdx::new(3U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
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
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([
        effect_type, result_type, result_type, indexed_type, result_type, result_type,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(99))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::array_new_fixed(array_type, @lib.U32(2U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::array_get(array_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::array_new_fixed(array_type, @lib.U32(2U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::array_get(array_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::array_new_fixed(array_type, @lib.U32(2U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::array_get(array_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::array_new_fixed(array_type, @lib.U32(2U)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_get(array_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(8)),
            @lib.Instruction::array_new_fixed(array_type, @lib.U32(2U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::array_get(array_type),
          ]),
        ),
      ]),
    ),
  )
  let get0 = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let get1 = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let dynidx = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  let oob = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  let effectful_sibling = optimized.pretty_print_func(@lib.FuncIdx::new(5U))
  assert_false(get0.contains("array.get"), msg=get0)
  assert_false(get0.contains("array.new_fixed"), msg=get0)
  assert_true(get0.contains("I32(7)"), msg=get0)
  assert_false(get1.contains("array.get"), msg=get1)
  assert_false(get1.contains("array.new_fixed"), msg=get1)
  assert_true(get1.contains("I32(8)"), msg=get1)
  assert_true(dynidx.contains("array.get"), msg=dynidx)
  assert_true(dynidx.contains("array.new_fixed"), msg=dynidx)
  assert_false(oob.contains("array.get"), msg=oob)
  assert_false(oob.contains("array.new_fixed"), msg=oob)
  assert_true(oob.contains("unreachable"), msg=oob)
  // Boundary-only half of this OI-K slice: Binaryen can preserve the effectful
  // sibling with a drop before forwarding, but Starshine keeps the stack form
  // until a safe localizing lowering preserves element-evaluation effects.
  assert_true(effectful_sibling.contains("array.get"), msg=effectful_sibling)
  assert_true(
    effectful_sibling.contains("array.new_fixed"),
    msg=effectful_sibling,
  )
  assert_true(
    effectful_sibling.contains("call (Func 0)"),
    msg=effectful_sibling,
  )
}

///|
test "optimize-instructions folds packed array.get_s and array.get_u of pure array.new_fixed elements" {
  let array_i8_type = @lib.TypeIdx::new(0U)
  let array_i16_type = @lib.TypeIdx::new(1U)
  let effect_type = @lib.TypeIdx::new(2U)
  let result_type = @lib.TypeIdx::new(3U)
  let indexed_type = @lib.TypeIdx::new(4U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::pack_type(@lib.PackType::i8()),
                @lib.Mut::const_(),
              ),
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::pack_type(@lib.PackType::i16()),
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
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([
        effect_type, result_type, result_type, result_type, result_type, indexed_type,
        indexed_type, indexed_type, result_type, result_type,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(99))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(255)),
            @lib.Instruction::i32_const(@lib.I32(128)),
            @lib.Instruction::array_new_fixed(array_i8_type, @lib.U32(2U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::array_get_s(array_i8_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(255)),
            @lib.Instruction::i32_const(@lib.I32(128)),
            @lib.Instruction::array_new_fixed(array_i8_type, @lib.U32(2U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::array_get_u(array_i8_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(65535)),
            @lib.Instruction::i32_const(@lib.I32(32768)),
            @lib.Instruction::array_new_fixed(array_i16_type, @lib.U32(2U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::array_get_s(array_i16_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(65535)),
            @lib.Instruction::i32_const(@lib.I32(32768)),
            @lib.Instruction::array_new_fixed(array_i16_type, @lib.U32(2U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::array_get_u(array_i16_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::array_new_fixed(array_i8_type, @lib.U32(2U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::array_get_s(array_i8_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::array_new_fixed(array_i16_type, @lib.U32(2U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::array_get_u(array_i16_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(255)),
            @lib.Instruction::i32_const(@lib.I32(128)),
            @lib.Instruction::array_new_fixed(array_i8_type, @lib.U32(2U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::array_get_s(array_i8_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(255)),
            @lib.Instruction::i32_const(@lib.I32(128)),
            @lib.Instruction::array_new_fixed(array_i8_type, @lib.U32(2U)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_get_s(array_i8_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::array_new_fixed(array_i8_type, @lib.U32(2U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::array_get_u(array_i8_type),
          ]),
        ),
      ]),
    ),
  )
  let s8_const = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let u8_const = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let s16_const = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  let u16_const = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  let s8_nonconst = optimized.pretty_print_func(@lib.FuncIdx::new(5U))
  let u16_nonconst = optimized.pretty_print_func(@lib.FuncIdx::new(6U))
  let dynidx = optimized.pretty_print_func(@lib.FuncIdx::new(7U))
  let oob = optimized.pretty_print_func(@lib.FuncIdx::new(8U))
  let effectful_sibling = optimized.pretty_print_func(@lib.FuncIdx::new(9U))
  assert_false(s8_const.contains("array.get"), msg=s8_const)
  assert_false(s8_const.contains("array.new_fixed"), msg=s8_const)
  assert_true(s8_const.contains("I32(-1)"), msg=s8_const)
  assert_false(u8_const.contains("array.get"), msg=u8_const)
  assert_true(u8_const.contains("I32(255)"), msg=u8_const)
  assert_false(s16_const.contains("array.get"), msg=s16_const)
  assert_true(s16_const.contains("I32(-32768)"), msg=s16_const)
  assert_false(u16_const.contains("array.get"), msg=u16_const)
  assert_true(u16_const.contains("I32(32768)"), msg=u16_const)
  assert_false(s8_nonconst.contains("array.get"), msg=s8_nonconst)
  assert_false(s8_nonconst.contains("array.new_fixed"), msg=s8_nonconst)
  assert_true(s8_nonconst.contains("i32.extend8s"), msg=s8_nonconst)
  assert_false(u16_nonconst.contains("array.get"), msg=u16_nonconst)
  assert_false(u16_nonconst.contains("array.new_fixed"), msg=u16_nonconst)
  assert_true(u16_nonconst.contains("i32.and"), msg=u16_nonconst)
  assert_true(u16_nonconst.contains("I32(65535)"), msg=u16_nonconst)
  assert_true(dynidx.contains("array.get_s"), msg=dynidx)
  assert_true(dynidx.contains("array.new_fixed"), msg=dynidx)
  assert_false(oob.contains("array.get"), msg=oob)
  assert_false(oob.contains("array.new_fixed"), msg=oob)
  assert_true(oob.contains("unreachable"), msg=oob)
  // Boundary-only half of this OI-K slice: Binaryen can preserve the effectful
  // sibling with a drop before forwarding, but Starshine keeps the stack form
  // until a safe localizing lowering preserves element-evaluation effects.
  assert_true(effectful_sibling.contains("array.get_u"), msg=effectful_sibling)
  assert_true(
    effectful_sibling.contains("array.new_fixed"),
    msg=effectful_sibling,
  )
  assert_true(
    effectful_sibling.contains("call (Func 0)"),
    msg=effectful_sibling,
  )
}

///|
test "optimize-instructions removes array.set to fresh pure arrays with constant indexes" {
  let array_type = @lib.TypeIdx::new(0U)
  let effect_type = @lib.TypeIdx::new(1U)
  let void_type = @lib.TypeIdx::new(2U)
  let indexed_void_type = @lib.TypeIdx::new(3U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
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
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], []),
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
    .with_func_sec(
      @lib.FuncSec::new([
        void_type, void_type, void_type, void_type, void_type, indexed_void_type,
        void_type,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_new_fixed(array_type, @lib.U32(2U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::array_set(array_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_new_fixed(array_type, @lib.U32(2U)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::array_set(array_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_new_default(array_type),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::array_set(array_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_new_fixed(array_type, @lib.U32(2U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::array_set(array_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_new_fixed(array_type, @lib.U32(2U)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::array_set(array_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_new_fixed(array_type, @lib.U32(2U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::array_set(array_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_new_fixed(array_type, @lib.U32(2U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::array_set(array_type),
          ]),
        ),
      ]),
    ),
  )
  let fixed_inbounds = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let fixed_oob = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let default_inbounds = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  let effect_inbounds = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  let effect_oob = optimized.pretty_print_func(@lib.FuncIdx::new(5U))
  let dynamic_index = optimized.pretty_print_func(@lib.FuncIdx::new(6U))
  let effectful_sibling = optimized.pretty_print_func(@lib.FuncIdx::new(7U))
  assert_false(fixed_inbounds.contains("array.set"), msg=fixed_inbounds)
  assert_false(fixed_inbounds.contains("array.new_fixed"), msg=fixed_inbounds)
  assert_false(fixed_oob.contains("array.set"), msg=fixed_oob)
  assert_false(fixed_oob.contains("array.new_fixed"), msg=fixed_oob)
  assert_true(fixed_oob.contains("unreachable"), msg=fixed_oob)
  assert_false(default_inbounds.contains("array.set"), msg=default_inbounds)
  assert_false(
    default_inbounds.contains("array.new_default"),
    msg=default_inbounds,
  )
  // Boundary-only half of this OI-K slice: Binaryen can preserve the effectful
  // set value with a drop before removing the unused set, but Starshine keeps
  // the stack form until a broader value-effect localizing proof is added.
  assert_true(effect_inbounds.contains("array.set"), msg=effect_inbounds)
  assert_true(effect_inbounds.contains("array.new_fixed"), msg=effect_inbounds)
  assert_true(effect_inbounds.contains("call (Func 0)"), msg=effect_inbounds)
  assert_true(effect_oob.contains("array.set"), msg=effect_oob)
  assert_true(effect_oob.contains("array.new_fixed"), msg=effect_oob)
  assert_true(effect_oob.contains("call (Func 0)"), msg=effect_oob)
  assert_true(dynamic_index.contains("array.set"), msg=dynamic_index)
  assert_true(dynamic_index.contains("array.new_fixed"), msg=dynamic_index)
  // Boundary-only half of this OI-K slice: Binaryen can preserve the effectful
  // sibling with a drop before removing the unused set, but Starshine keeps the
  // stack form until a broader constructor-effect localizing proof is added.
  assert_true(effectful_sibling.contains("array.set"), msg=effectful_sibling)
  assert_true(
    effectful_sibling.contains("array.new_fixed"),
    msg=effectful_sibling,
  )
  assert_true(
    effectful_sibling.contains("call (Func 0)"),
    msg=effectful_sibling,
  )
}

///|
test "optimize-instructions removes array.set to fresh pure array.new repeated-value arrays with constant indexes" {
  let array_type = @lib.TypeIdx::new(0U)
  let effect_type = @lib.TypeIdx::new(1U)
  let void_type = @lib.TypeIdx::new(2U)
  let indexed_void_type = @lib.TypeIdx::new(3U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
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
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], []),
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
    .with_func_sec(
      @lib.FuncSec::new([
        void_type, void_type, void_type, void_type, indexed_void_type, void_type,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        // set_new_inbounds_pure: array.set(array.new(7, 2), 1, 9) -> nop.
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_new(array_type),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::array_set(array_type),
          ]),
        ),
        // set_new_oob_pure: array.set(array.new(7, 2), 2, 9) -> unreachable.
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_new(array_type),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::array_set(array_type),
          ]),
        ),
        // set_new_effect_setval: effectful set value is preserved (boundary).
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_new(array_type),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::array_set(array_type),
          ]),
        ),
        // set_new_effect_value: effectful repeated value is preserved (boundary).
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_new(array_type),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::array_set(array_type),
          ]),
        ),
        // set_new_dynamic_len: dynamic length may trap on allocation (boundary).
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::array_new(array_type),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::array_set(array_type),
          ]),
        ),
        // set_new_huge_len: huge length traps on allocation (boundary).
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::i32_const(@lib.I32(2147483647)),
            @lib.Instruction::array_new(array_type),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::array_set(array_type),
          ]),
        ),
      ]),
    ),
  )
  let new_inbounds = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let new_oob = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let effect_setval = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  let effect_value = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  let dynamic_len = optimized.pretty_print_func(@lib.FuncIdx::new(5U))
  let huge_len = optimized.pretty_print_func(@lib.FuncIdx::new(6U))
  assert_false(new_inbounds.contains("array.set"), msg=new_inbounds)
  assert_false(new_inbounds.contains("array.new"), msg=new_inbounds)
  assert_false(new_oob.contains("array.set"), msg=new_oob)
  assert_false(new_oob.contains("array.new"), msg=new_oob)
  assert_true(new_oob.contains("unreachable"), msg=new_oob)
  // Boundary-only half of this OI-K slice: Binaryen localizes the effectful set
  // value with a drop before removing the unused set, but Starshine keeps the
  // stack form until a broader value-effect localizing proof is added.
  assert_true(effect_setval.contains("array.set"), msg=effect_setval)
  assert_true(effect_setval.contains("array.new"), msg=effect_setval)
  assert_true(effect_setval.contains("call (Func 0)"), msg=effect_setval)
  // Boundary-only half: effectful repeated-value constructor operand.
  assert_true(effect_value.contains("array.set"), msg=effect_value)
  assert_true(effect_value.contains("array.new"), msg=effect_value)
  assert_true(effect_value.contains("call (Func 0)"), msg=effect_value)
  // Boundary-only half: dynamic length may trap on allocation, so the fresh
  // producer and its set must stay until a safe non-trapping length proof exists.
  assert_true(dynamic_len.contains("array.set"), msg=dynamic_len)
  assert_true(dynamic_len.contains("array.new"), msg=dynamic_len)
  // Boundary-only half: huge constant length traps on allocation.
  assert_true(huge_len.contains("array.set"), msg=huge_len)
  assert_true(huge_len.contains("array.new"), msg=huge_len)
}

///|
test "optimize-instructions keeps array.fill and array.copy on fresh arrays as a Binaryen OI parity boundary" {
  // Boundary-only OI-K classification: Binaryen `version_130`
  // `--optimize-instructions` (both direct and O4z-style `-O`) does NOT fold
  // `array.fill` or `array.copy` on fresh one-use pure arrays, even for pure
  // in-bounds or out-of-bounds shapes (probe `.tmp/oi-k-array-fill-probe.wat`
  // and `.tmp/oi-k-array-copy-probe.wat`). Starshine keeping these unchanged
  // is therefore correct OI parity, not a gap. This test locks that boundary so
  // any future OI folding of these bulk array ops forces a fresh Binaryen
  // parity / Starshine-win review.
  let array_type = @lib.TypeIdx::new(0U)
  let void_type = @lib.TypeIdx::new(1U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
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
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([void_type, void_type, void_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        // array.fill over a fresh one-use array.new_fixed (pure, in-bounds).
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_new_fixed(array_type, @lib.U32(2U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_fill(array_type),
          ]),
        ),
        // array.fill over a fresh one-use array.new_default (pure, in-bounds).
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_new_default(array_type),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(9)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_fill(array_type),
          ]),
        ),
        // array.copy between two fresh one-use array.new_default (pure, in-bounds).
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_new_default(array_type),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_new_default(array_type),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_copy(array_type, array_type),
          ]),
        ),
      ]),
    ),
  )
  let fill_fixed = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let fill_default = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let copy_fresh = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(fill_fixed.contains("array.fill"), msg=fill_fixed)
  assert_true(fill_default.contains("array.fill"), msg=fill_default)
  assert_true(copy_fresh.contains("array.copy"), msg=copy_fresh)
}

///|
test "optimize-instructions folds array.get of constant-size array.new repeated values" {
  let array_i32_type = @lib.TypeIdx::new(0U)
  let array_i8_type = @lib.TypeIdx::new(1U)
  let array_i16_type = @lib.TypeIdx::new(2U)
  let result_type = @lib.TypeIdx::new(3U)
  let param_result_type = @lib.TypeIdx::new(4U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
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
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::pack_type(@lib.PackType::i8()),
                @lib.Mut::const_(),
              ),
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::pack_type(@lib.PackType::i16()),
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
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([
        result_type, result_type, param_result_type, result_type, result_type, result_type,
        result_type, param_result_type, param_result_type, result_type, result_type,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(99))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::array_new(array_i32_type),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::array_get(array_i32_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::array_new(array_i32_type),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::array_get(array_i32_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::array_new(array_i32_type),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::array_get(array_i32_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::array_new(array_i32_type),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::array_get(array_i32_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::array_new(array_i32_type),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::array_get(array_i32_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(255)),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::array_new(array_i8_type),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::array_get_s(array_i8_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::array_new(array_i16_type),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::array_get_u(array_i16_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::array_new(array_i32_type),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::array_get(array_i32_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::i32_const(@lib.I32(-1)),
            @lib.Instruction::array_new(array_i32_type),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::array_get(array_i32_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::i32_const(@lib.I32(2147483647)),
            @lib.Instruction::array_new(array_i32_type),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::array_get(array_i32_type),
          ]),
        ),
      ]),
    ),
  )
  let const_value = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let local_value = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let effect_value = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  let pure_oob = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  let effect_oob = optimized.pretty_print_func(@lib.FuncIdx::new(5U))
  let s8 = optimized.pretty_print_func(@lib.FuncIdx::new(6U))
  let u16_local = optimized.pretty_print_func(@lib.FuncIdx::new(7U))
  let dynamic_index = optimized.pretty_print_func(@lib.FuncIdx::new(8U))
  let negative_len = optimized.pretty_print_func(@lib.FuncIdx::new(9U))
  let huge_len = optimized.pretty_print_func(@lib.FuncIdx::new(10U))
  for pretty in [const_value, local_value, effect_value, s8, u16_local] {
    assert_false(pretty.contains("array.get"), msg=pretty)
    assert_false(pretty.contains("array.new"), msg=pretty)
  }
  assert_true(const_value.contains("I32(7)"), msg=const_value)
  assert_true(local_value.contains("local.get (Local 0)"), msg=local_value)
  assert_true(effect_value.contains("call (Func 0)"), msg=effect_value)
  assert_false(pure_oob.contains("array.get"), msg=pure_oob)
  assert_false(pure_oob.contains("array.new"), msg=pure_oob)
  assert_true(pure_oob.contains("unreachable"), msg=pure_oob)
  assert_true(s8.contains("I32(-1)"), msg=s8)
  assert_true(u16_local.contains("i32.and"), msg=u16_local)
  assert_true(u16_local.contains("I32(65535)"), msg=u16_local)
  assert_true(dynamic_index.contains("array.get"), msg=dynamic_index)
  assert_true(dynamic_index.contains("array.new"), msg=dynamic_index)
  // Boundary-only half of this OI-K slice: Binaryen can preserve an effectful
  // repeated value with a drop before the out-of-bounds trap, but Starshine
  // keeps the stack form until safe localizing lowering can preserve the call.
  assert_true(effect_oob.contains("array.get"), msg=effect_oob)
  assert_true(effect_oob.contains("array.new"), msg=effect_oob)
  assert_true(effect_oob.contains("call (Func 0)"), msg=effect_oob)
  // Boundary-only half of this OI-K slice: trap-preserving length limits mirror
  // the array.new len slice and keep negative/huge allocation traps intact.
  assert_true(negative_len.contains("array.get"), msg=negative_len)
  assert_true(negative_len.contains("array.new"), msg=negative_len)
  assert_true(huge_len.contains("array.get"), msg=huge_len)
  assert_true(huge_len.contains("array.new"), msg=huge_len)
}

///|
test "optimize-instructions folds array.get of constant-size array.new_default defaults" {
  let array_i32_type = @lib.TypeIdx::new(0U)
  let array_i8_type = @lib.TypeIdx::new(1U)
  let array_i16_type = @lib.TypeIdx::new(2U)
  let result_type = @lib.TypeIdx::new(3U)
  let indexed_type = @lib.TypeIdx::new(4U)
  let optimized = optimize_instructions_test_run_module(
    @lib.Module::new()
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
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::pack_type(@lib.PackType::i8()),
                @lib.Mut::const_(),
              ),
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::pack_type(@lib.PackType::i16()),
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
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([
        result_type, result_type, result_type, result_type, result_type, indexed_type,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::array_new_default(array_i32_type),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::array_get(array_i32_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_new_default(array_i8_type),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::array_get_s(array_i8_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_new_default(array_i8_type),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::array_get_u(array_i8_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::array_new_default(array_i16_type),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::array_get_s(array_i16_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::array_new_default(array_i32_type),
            @lib.Instruction::i32_const(@lib.I32(3)),
            @lib.Instruction::array_get(array_i32_type),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::array_new_default(array_i32_type),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::array_get(array_i32_type),
          ]),
        ),
      ]),
    ),
  )
  let plain = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let s8 = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  let u8 = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  let s16 = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  let oob = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  let dynamic_len = optimized.pretty_print_func(@lib.FuncIdx::new(5U))
  for pretty in [plain, s8, u8, s16] {
    assert_false(pretty.contains("array.get"), msg=pretty)
    assert_false(pretty.contains("array.new_default"), msg=pretty)
    assert_true(pretty.contains("I32(0)"), msg=pretty)
  }
  assert_false(oob.contains("array.get"), msg=oob)
  assert_false(oob.contains("array.new_default"), msg=oob)
  assert_true(oob.contains("unreachable"), msg=oob)
  // Boundary-only half of this OI-K slice: without a constant length, Starshine
  // cannot prove that a constant index is in-bounds or out-of-bounds.
  assert_true(dynamic_len.contains("array.get"), msg=dynamic_len)
  assert_true(dynamic_len.contains("array.new_default"), msg=dynamic_len)
}

///|
test "optimize-instructions intentionally keeps struct.get of struct.new with effectful sibling fields" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (type $s (struct (field i32) (field i32)))
        #|  (import "env" "a" (func $a (result i32)))
        #|  (import "env" "b" (func $b (result i32)))
        #|  (func (export "get0") (result i32)
        #|    call $a
        #|    call $b
        #|    struct.new $s
        #|    struct.get $s 0))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected effectful struct.get(struct.new) boundary success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  // Boundary-only OI-K coverage: Binaryen can localize and drop effectful sibling
  // fields before replacing the allocation, but Starshine keeps this stack-carried
  // shape until a safe localizing lowering preserves field-evaluation effects.
  assert_true(pretty.contains("struct.get"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
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
test "optimize-instructions canonicalizes leading commutative constants" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) i32.const 7 local.get 0 i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected non-constant commutative operand to move to the lhs")
  }
  let rhs_node = @ir.hot_node_get(func, rhs)
  match rhs_node.op {
    @ir.HotOp::Const => ()
    _ => fail("expected leading commutative constant to move to the rhs")
  }
  @debug.assert_eq(
    @ir.hot_const_get(func, rhs_node.imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(7)),
  )
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
test "optimize-instructions rewrites unsigned div and rem by a power of two" {
  let div_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 8 i32.div_u))",
  )
  let div_root = @ir.hot_root_get(div_func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(div_func, div_root),
    Some(@lib.Instruction::i32_shr_u()),
  )
  let div_rhs = @ir.hot_child_get(div_func, div_root, 1)
  @debug.assert_eq(
    @ir.hot_const_get(div_func, @ir.hot_node_get(div_func, div_rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(3)),
  )
  let rem_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 8 i32.rem_u))",
  )
  let rem_root = @ir.hot_root_get(rem_func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(rem_func, rem_root),
    Some(@lib.Instruction::i32_and()),
  )
  let rem_rhs = @ir.hot_child_get(rem_func, rem_root, 1)
  @debug.assert_eq(
    @ir.hot_const_get(rem_func, @ir.hot_node_get(rem_func, rem_rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(7)),
  )
  let i64_div_func = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i64) local.get 0 i64.const 16 i64.div_u))",
  )
  let i64_div_root = @ir.hot_root_get(i64_div_func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(i64_div_func, i64_div_root),
    Some(@lib.Instruction::i64_shr_u()),
  )
  let i64_rem_func = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i64) local.get 0 i64.const 16 i64.rem_u))",
  )
  let i64_rem_root = @ir.hot_root_get(i64_rem_func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(i64_rem_func, i64_rem_root),
    Some(@lib.Instruction::i64_and()),
  )
  let i64_rem_rhs = @ir.hot_child_get(i64_rem_func, i64_rem_root, 1)
  @debug.assert_eq(
    @ir.hot_const_get(
      i64_rem_func,
      @ir.hot_node_get(i64_rem_func, i64_rem_rhs).imm0,
    ),
    @ir.HotConstPayload::i64_const(@lib.I64(15L)),
  )
  let non_pow2_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 6 i32.div_u))",
  )
  let non_pow2_root = @ir.hot_root_get(non_pow2_func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(non_pow2_func, non_pow2_root),
    Some(@lib.Instruction::i32_div_u()),
  )
  let signed_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 8 i32.div_s))",
  )
  let signed_root = @ir.hot_root_get(signed_func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(signed_func, signed_root),
    Some(@lib.Instruction::i32_div_s()),
  )
  let lhs_const_func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) i32.const 4 local.get 0 i32.div_u))",
  )
  let lhs_const_root = @ir.hot_root_get(lhs_const_func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(lhs_const_func, lhs_const_root),
    Some(@lib.Instruction::i32_div_u()),
  )
}

///|
test "optimize-instructions canonicalizes leading i64.mul const before shift rewrite" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i64) i64.const 4 local.get 0 i64.mul))",
  )
  let root = @ir.hot_root_get(func, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, root),
    Some(@lib.Instruction::i64_shl()),
  )
  match @ir.hot_node_get(func, @ir.hot_child_get(func, root, 0)).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected i64.mul local operand to move before shift amount")
  }
  let rhs = @ir.hot_child_get(func, root, 1)
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, rhs).imm0),
    @ir.HotConstPayload::i64_const(@lib.I64(2L)),
  )
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
test "optimize-instructions canonicalizes shifted lhs after rhs local get" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32 i32) (result i32) local.get 1 i32.const 1 i32.shl local.get 0 i32.add))",
  )
  let root = @ir.hot_root_get(func, 0)
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected rhs local.get to move before shifted lhs")
  }
  @debug.assert_eq(@ir.hot_node_get(func, lhs).imm0, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(func, rhs),
    Some(@lib.Instruction::i32_shl()),
  )
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
test "optimize-instructions keeps local tee before same-local get" {
  let func = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) (local i32) local.get 0 local.tee 1 local.get 1 i32.eq))",
  )
  let root = @ir.hot_root_get(func, 0)
  let lhs = @ir.hot_child_get(func, root, 0)
  let rhs = @ir.hot_child_get(func, root, 1)
  match @ir.hot_node_get(func, lhs).op {
    @ir.HotOp::LocalTee => ()
    _ => fail("expected local.tee subtree to stay before same-local get")
  }
  match @ir.hot_node_get(func, rhs).op {
    @ir.HotOp::LocalGet => ()
    _ => fail("expected same-local get to stay behind local.tee")
  }
  @debug.assert_eq(@ir.hot_node_get(func, rhs).imm0, 1)
}

///|
test "optimize-instructions canonicalizes commutative local get pair order" {
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
  @debug.assert_eq(@ir.hot_node_get(func, lhs).imm0, 1)
  @debug.assert_eq(@ir.hot_node_get(func, rhs).imm0, 2)
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
test "optimize-instructions combines nested constant shifts" {
  let shl_i32 = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 3 i32.shl i32.const 5 i32.shl))",
  )
  let shl_i32_root = @ir.hot_root_get(shl_i32, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(shl_i32, shl_i32_root),
    Some(@lib.Instruction::i32_shl()),
  )
  let shl_i32_rhs = @ir.hot_child_get(shl_i32, shl_i32_root, 1)
  @debug.assert_eq(
    @ir.hot_const_get(shl_i32, @ir.hot_node_get(shl_i32, shl_i32_rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(8)),
  )

  let shl_i64 = optimize_instructions_test_run_hot(
    "(module (func (param i64) (result i64) local.get 0 i64.const 3 i64.shl i64.const 5 i64.shl))",
  )
  let shl_i64_root = @ir.hot_root_get(shl_i64, 0)
  @debug.assert_eq(
    @ir.hot_node_exact_instr(shl_i64, shl_i64_root),
    Some(@lib.Instruction::i64_shl()),
  )
  let shl_i64_rhs = @ir.hot_child_get(shl_i64, shl_i64_root, 1)
  @debug.assert_eq(
    @ir.hot_const_get(shl_i64, @ir.hot_node_get(shl_i64, shl_i64_rhs).imm0),
    @ir.HotConstPayload::i64_const(@lib.I64(8L)),
  )

  let shr_u_i32 = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 4 i32.shr_u i32.const 2 i32.shr_u))",
  )
  let shr_u_i32_root = @ir.hot_root_get(shr_u_i32, 0)
  let shr_u_i32_rhs = @ir.hot_child_get(shr_u_i32, shr_u_i32_root, 1)
  @debug.assert_eq(
    @ir.hot_const_get(
      shr_u_i32,
      @ir.hot_node_get(shr_u_i32, shr_u_i32_rhs).imm0,
    ),
    @ir.HotConstPayload::i32_const(@lib.I32(6)),
  )

  let shr_s_i32 = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 4 i32.shr_s i32.const 2 i32.shr_s))",
  )
  let shr_s_i32_root = @ir.hot_root_get(shr_s_i32, 0)
  let shr_s_i32_rhs = @ir.hot_child_get(shr_s_i32, shr_s_i32_root, 1)
  @debug.assert_eq(
    @ir.hot_const_get(
      shr_s_i32,
      @ir.hot_node_get(shr_s_i32, shr_s_i32_rhs).imm0,
    ),
    @ir.HotConstPayload::i32_const(@lib.I32(6)),
  )

  let rotl_i32 = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 3 i32.rotl i32.const 5 i32.rotl))",
  )
  let rotl_i32_root = @ir.hot_root_get(rotl_i32, 0)
  let rotl_i32_rhs = @ir.hot_child_get(rotl_i32, rotl_i32_root, 1)
  @debug.assert_eq(
    @ir.hot_const_get(rotl_i32, @ir.hot_node_get(rotl_i32, rotl_i32_rhs).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(8)),
  )

  let masked_shl_i32 = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 3 i32.shl i32.const 5 i32.const 31 i32.and i32.shl))",
  )
  let masked_shl_i32_root = @ir.hot_root_get(masked_shl_i32, 0)
  let masked_shl_i32_rhs = @ir.hot_child_get(
    masked_shl_i32, masked_shl_i32_root, 1,
  )
  @debug.assert_eq(
    @ir.hot_const_get(
      masked_shl_i32,
      @ir.hot_node_get(masked_shl_i32, masked_shl_i32_rhs).imm0,
    ),
    @ir.HotConstPayload::i32_const(@lib.I32(8)),
  )

  let wrap_shl_i32 = optimize_instructions_test_run_hot(
    "(module (func (param i32) (result i32) local.get 0 i32.const 3 i32.shl i32.const 28 i32.shl))",
  )
  let wrap_shl_i32_root = @ir.hot_root_get(wrap_shl_i32, 0)
  let wrap_shl_i32_rhs = @ir.hot_child_get(wrap_shl_i32, wrap_shl_i32_root, 1)
  @debug.assert_eq(
    @ir.hot_const_get(
      wrap_shl_i32,
      @ir.hot_node_get(wrap_shl_i32, wrap_shl_i32_rhs).imm0,
    ),
    @ir.HotConstPayload::i32_const(@lib.I32(31)),
  )
}

///|
test "optimize-instructions folds or with all-ones absorbing operand" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (import "m" "effect" (func $effect (result i32)))
        #|  (func $id (param $x i32) (param $y i64)
        #|    local.get $x
        #|    i32.const -1
        #|    i32.or
        #|    drop
        #|    i32.const -1
        #|    local.get $x
        #|    i32.or
        #|    drop
        #|    local.get $y
        #|    i64.const -1
        #|    i64.or
        #|    drop
        #|    i64.const -1
        #|    local.get $y
        #|    i64.or
        #|    drop)
        #|  (func $or_effect_rhs (result i32)
        #|    call $effect
        #|    i32.const -1
        #|    i32.or)
        #|  (func $or_effect_lhs (result i32)
        #|    i32.const -1
        #|    call $effect
        #|    i32.or))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected or-all-ones absorbing optimize success, got \{err}")
  }
  let id_pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(id_pretty.contains("i32.or"), msg=id_pretty)
  assert_false(id_pretty.contains("i64.or"), msg=id_pretty)
  assert_true(id_pretty.contains("I32(-1)"), msg=id_pretty)
  assert_true(id_pretty.contains("I64(-1)"), msg=id_pretty)

  let or_effect_rhs = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (import "m" "effect" (func $effect (result i32)))
        #|  (func (result i32)
        #|    call $effect
        #|    i32.const -1
        #|    i32.or))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected or-effect-rhs optimize success, got \{err}")
  }
  let or_effect_rhs_trace = match
    pass_test_capture_trace(
      (
        #|(module
        #|  (import "m" "effect" (func $effect (result i32)))
        #|  (func (result i32)
        #|    call $effect
        #|    i32.const -1
        #|    i32.or))
        #|,
      ),
      ["optimize-instructions"],
    ) {
    Ok(lines) => lines
    Err(err) => fail("expected or-effect-rhs trace success, got \{err}")
  }
  assert_false(
    or_effect_rhs_trace.any(fn(line) {
      line.contains("optimize-instructions") && line.contains("skip")
    }),
    msg=or_effect_rhs_trace.to_string(),
  )
  let or_effect_rhs_pretty = or_effect_rhs.pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_false(
    or_effect_rhs_pretty.contains("i32.or"),
    msg=or_effect_rhs_pretty,
  )
  assert_true(or_effect_rhs_pretty.contains("call"), msg=or_effect_rhs_pretty)
  assert_true(
    or_effect_rhs_pretty.contains("I32(-1)"),
    msg=or_effect_rhs_pretty,
  )
}

///|
test "optimize-instructions folds effectful or with all-ones on hot ir" {
  let mod_ = pass_test_module_from_wat(
    "(module (import \"m\" \"effect\" (func $effect (result i32))) (func (result i32) call $effect i32.const -1 i32.or))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(1U))
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
      fail("expected effectful or-all-ones hot optimize success, got \{err}")
  }
  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block => {
      let body = @ir.hot_region_body_ref(func, root)
      @debug.assert_eq(@ir.hot_region_root_count(func, body), 2)
      let first = @ir.hot_region_get(func, body, 0)
      let second = @ir.hot_region_get(func, body, 1)
      match @ir.hot_node_get(func, first).op {
        @ir.HotOp::Drop => ()
        _ => fail("expected drop before all-ones or fold")
      }
      match @ir.hot_node_get(func, second).op {
        @ir.HotOp::Const => ()
        _ => fail("expected const -1 after effectful or fold")
      }
    }
    @ir.HotOp::Const => ()
    _ => fail("expected effectful or with -1 to fold to block or const")
  }
}

///|
test "optimize-instructions folds effectful or with all-ones lhs on hot ir" {
  let mod_ = pass_test_module_from_wat(
    "(module (import \"m\" \"effect\" (func $effect (result i32))) (func (result i32) i32.const -1 call $effect i32.or))",
  )
  let func = @ir.hot_lift_func(mod_, @lib.FuncIdx::new(1U))
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
        "expected effectful lhs or-all-ones hot optimize success, got \{err}",
      )
  }
  let root = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, root).op {
    @ir.HotOp::Block | @ir.HotOp::Const => ()
    _ => fail("expected lhs effectful or with -1 to fold")
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
