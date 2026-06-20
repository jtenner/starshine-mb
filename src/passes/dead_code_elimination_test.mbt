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
fn dead_code_elimination_test_index_of(text : String, needle : String) -> Int? {
  if needle == "" {
    return Some(0)
  }
  if needle.length() > text.length() {
    return None
  }
  let mut i = 0
  while i <= text.length() - needle.length() {
    if text.sub(start=i, end=i + needle.length()).to_owned() == needle {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn dead_code_elimination_test_gc_ref(
  nullable : Bool,
  abs : @lib.AbsHeapType,
) -> @lib.ValType {
  @lib.ValType::ref_type(@lib.RefType::new(nullable, @lib.HeapType::abs(abs)))
}

///|
fn dead_code_elimination_test_gc_branch_module(
  block_results : Array[@lib.ValType],
  body : Array[@lib.Instruction],
) -> @lib.Module {
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], block_results)),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::new([]), @lib.Expr::new(body)),
    ]),
  )
}

///|
fn dead_code_elimination_test_run_gc_branch_pretty(
  mod_ : @lib.Module,
) -> String {
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) => abort("unexpected invalid DCE GC branch fixture: \{err}")
  }
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected DCE GC branch pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => optimized.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => abort("expected DCE GC branch output to validate, got \{err}")
  }
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
test "dead-code-elimination preserves binary operands before unreachable child" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (drop (i32.add (call $side) (block (result i32) nop unreachable)))) (func $side (result i32) i32.const 99))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected binary unreachable-second-child DCE success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
}

///|
test "dead-code-elimination preserves store address before unreachable value" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func $side (result i32) i32.const 16) (func (i32.store (call $side) (block (result i32) nop unreachable))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected store unreachable-value DCE success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("i32.store"), msg=pretty)
}

///|
test "dead-code-elimination preserves memory.fill destination before unreachable value" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func $dest (result i32) i32.const 8) (func $size (result i32) i32.const 4) (func (memory.fill (call $dest) (block (result i32) nop unreachable) (call $size))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected memory.fill unreachable-value DCE success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
  assert_false(pretty.contains("memory.fill"), msg=pretty)
}

///|
test "dead-code-elimination preserves evaluated direct-call operand before unreachable argument" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $lhs (result i32) i32.const 1) (func $rhs (result i32) i32.const 2) (func $sink (param i32 i32 i32)) (func (call $sink (call $lhs) (block (result i32) nop unreachable) (call $rhs))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected direct-call unreachable-argument DCE success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
  assert_false(pretty.contains("Func 2"), msg=pretty)
}

///|
test "dead-code-elimination trims call_indirect consumer after unreachable argument" {
  let source =
    #|(module
    #|  (type $sink-type (func (param i32 i32 i32)))
    #|  (table 1 funcref)
    #|  (func $lhs (result i32) i32.const 1)
    #|  (func $rhs (result i32) i32.const 2)
    #|  (func $sink (type $sink-type))
    #|  (elem (i32.const 0) $sink)
    #|  (func
    #|    (call_indirect (type $sink-type)
    #|      (call $lhs)
    #|      (block (result i32) nop unreachable)
    #|      (call $rhs)
    #|      (i32.const 0))))
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected call_indirect unreachable-argument DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
  assert_false(pretty.contains("call_indirect"), msg=pretty)
}

///|
test "dead-code-elimination trims call_ref consumer after unreachable argument" {
  let source =
    #|(module
    #|  (type $sink-type (func (param i32 i32 i32)))
    #|  (func $lhs (result i32) i32.const 1)
    #|  (func $rhs (result i32) i32.const 2)
    #|  (func $sink (type $sink-type))
    #|  (elem declare func $sink)
    #|  (func
    #|    (call_ref (type $sink-type)
    #|      (call $lhs)
    #|      (block (result i32) nop unreachable)
    #|      (call $rhs)
    #|      (ref.func $sink))))
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected call_ref unreachable-argument DCE success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
  assert_false(pretty.contains("call_ref"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and multi-instruction later operand" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $lhs (result i32) i32.const 1) (func $rhs1 (result i32) i32.const 2) (func $rhs2 (result i32) i32.const 3) (func $sink (param i32 i32 i32)) (func (call $sink (call $lhs) (block (result i32) nop unreachable) (i32.add (call $rhs1) (call $rhs2)))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument multi-instruction suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(4U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
  assert_false(pretty.contains("Func 2"), msg=pretty)
  assert_false(pretty.contains("Func 3"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
}

///|
test "dead-code-elimination preserves multi-instruction evaluated argument before unreachable argument" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $lhs (result i32) i32.const 1) (func $mid1 (result i32) i32.const 2) (func $mid2 (result i32) i32.const 3) (func $rhs (result i32) i32.const 4) (func $sink (param i32 i32 i32 i32)) (func (call $sink (call $lhs) (i32.add (call $mid1) (call $mid2)) (block (result i32) nop unreachable) (call $rhs))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument multi-instruction prefix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(5U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("call (Func 1)"), msg=pretty)
  assert_true(pretty.contains("call (Func 2)"), msg=pretty)
  assert_true(pretty.contains("i32.add"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("Func 3"), msg=pretty)
  assert_false(pretty.contains("Func 4"), msg=pretty)
}

///|
test "dead-code-elimination trims br consumer after unreachable block payload" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (block (result i32) (i32.const 7) (block (result i32) nop unreachable) br 0) drop))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected br consumer DCE success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "dead-code-elimination trims br_table consumer after unreachable block payload" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (block (result i32) (i32.const 7) (block (result i32) nop unreachable) i32.const 0 br_table 0 0) drop))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected br_table consumer DCE success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("br_table"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "dead-code-elimination trims br_if consumer after unreachable block payload" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (block (result i32) (i32.const 7) (block (result i32) nop unreachable) i32.const 0 br_if 0) drop))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected br_if consumer DCE success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("br_if"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "dead-code-elimination trims ref branch consumers after unreachable payload" {
  let i31_ref = dead_code_elimination_test_gc_ref(
    false,
    @lib.AbsHeapType::i31(),
  )
  let any_ref = dead_code_elimination_test_gc_ref(true, @lib.AbsHeapType::any())
  let block_sig = [@lib.ValType::i32(), i31_ref]
  let label = @lib.LabelIdx::new(0U)
  let dead_i32 = @lib.Instruction::block(
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @lib.Expr::new([@lib.Instruction::nop(), @lib.Instruction::unreachable_()]),
  )
  let suffix_result = [
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32::new(1)),
    @lib.Instruction::ref_i31(),
  ]
  let cases : Array[(String, @lib.Module)] = [
    (
      "br_on_null",
      dead_code_elimination_test_gc_branch_module([@lib.ValType::i32()], [
        @lib.Instruction::block(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32::new(7)),
            dead_i32,
            @lib.Instruction::ref_null(
              @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
            ),
            @lib.Instruction::br_on_null(label),
            @lib.Instruction::drop(),
          ]),
        ),
        @lib.Instruction::drop(),
      ]),
    ),
    (
      "br_on_non_null",
      dead_code_elimination_test_gc_branch_module(block_sig, [
        @lib.Instruction::block(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
          @lib.Expr::new(
            [
              @lib.Instruction::i32_const(@lib.I32::new(7)),
              dead_i32,
              @lib.Instruction::i32_const(@lib.I32::new(0)),
              @lib.Instruction::ref_i31(),
              @lib.Instruction::br_on_non_null(label),
              ..suffix_result,
            ],
          ),
        ),
        @lib.Instruction::drop(),
        @lib.Instruction::drop(),
      ]),
    ),
    (
      "br_on_cast",
      dead_code_elimination_test_gc_branch_module(block_sig, [
        @lib.Instruction::block(
          @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
          @lib.Expr::new(
            [
              @lib.Instruction::i32_const(@lib.I32::new(7)),
              dead_i32,
              @lib.Instruction::ref_null(
                @lib.HeapType::abs(@lib.AbsHeapType::any()),
              ),
              @lib.Instruction::br_on_cast(
                label,
                true,
                @lib.HeapType::abs(@lib.AbsHeapType::any()),
                false,
                @lib.HeapType::abs(@lib.AbsHeapType::i31()),
              ),
              ..suffix_result,
            ],
          ),
        ),
        @lib.Instruction::drop(),
        @lib.Instruction::drop(),
      ]),
    ),
    (
      "br_on_cast_fail",
      dead_code_elimination_test_gc_branch_module(
        [@lib.ValType::i32(), any_ref],
        [
          @lib.Instruction::block(
            @lib.BlockType::type_idx(@lib.TypeIdx::new(1U)),
            @lib.Expr::new([
              @lib.Instruction::i32_const(@lib.I32::new(7)),
              dead_i32,
              @lib.Instruction::ref_null(
                @lib.HeapType::abs(@lib.AbsHeapType::any()),
              ),
              @lib.Instruction::br_on_cast_fail(
                label,
                true,
                @lib.HeapType::abs(@lib.AbsHeapType::any()),
                false,
                @lib.HeapType::abs(@lib.AbsHeapType::i31()),
              ),
              @lib.Instruction::drop(),
              @lib.Instruction::ref_null(
                @lib.HeapType::abs(@lib.AbsHeapType::any()),
              ),
            ]),
          ),
          @lib.Instruction::drop(),
          @lib.Instruction::drop(),
        ],
      ),
    ),
  ]
  for case in cases {
    let (name, mod_) = case
    let pretty = dead_code_elimination_test_run_gc_branch_pretty(mod_)
    assert_false(pretty.contains(name), msg=pretty)
    assert_true(pretty.contains("I32(7)"), msg=pretty)
    assert_true(pretty.contains("drop"), msg=pretty)
    assert_true(pretty.contains("unreachable"), msg=pretty)
  }
}

///|
test "dead-code-elimination trims return consumer after unreachable result and dead later result" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32 i32) (i32.const 1) (block (result i32) nop unreachable) (i32.const 2) return))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected return unreachable-result DCE success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_false(pretty.contains("I32(2)"), msg=pretty)
  assert_false(pretty.contains("return"), msg=pretty)
}

///|
test "dead-code-elimination trims throw consumer after unreachable payload and dead later payload" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (type $tag_payloads (func (param i32 i32 i32)))
        #|  (tag $e (type $tag_payloads))
        #|  (func $lhs (result i32) i32.const 1)
        #|  (func
        #|    (call $lhs)
        #|    (block (result i32) nop unreachable)
        #|    (i32.const 2)
        #|    (throw $e)))
      ),
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected throw unreachable-payload dead suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("I32(2)"), msg=pretty)
  assert_false(pretty.contains("throw"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later block result" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $lhs (result i32) i32.const 1) (func $sink (param i32 i32 i32)) (func (call $sink (call $lhs) (block (result i32) nop unreachable) (block (result i32) i32.const 9))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-block-result suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("i32.const I32(9)"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later loop result" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $lhs (result i32) i32.const 1) (func $sink (param i32 i32 i32)) (func (call $sink (call $lhs) (block (result i32) nop unreachable) (loop (result i32) i32.const 9))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-loop-result suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("i32.const I32(9)"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination drops evaluated prefix before voidified if nonfallthrough argument" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $lhs (result i32) i32.const 1) (func $cond (result i32) i32.const 0) (func $sink (param i32 i32 i32)) (func (call $sink (call $lhs) (if (result i32) (call $cond) (then unreachable) (else unreachable)) (i32.const 9))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call dead-if-nonfallthrough-argument DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("call (Func 1)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("I32(9)"), msg=pretty)
  assert_false(pretty.contains("Func 2"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later if result" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $lhs (result i32) i32.const 1) (func $sink (param i32 i32 i32)) (func (call $sink (call $lhs) (block (result i32) nop unreachable) (if (result i32) (i32.const 1) (then i32.const 9) (else i32.const 10)))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-if-result suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("i32.const I32(9)"), msg=pretty)
  assert_false(pretty.contains("i32.const I32(10)"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after nonfallthrough try_table argument" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $lhs (result i32) i32.const 1) (func $sink (param i32 i32 i32)) (func (call $sink (call $lhs) (try_table (result i32) unreachable) (i32.const 9))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call nonfallthrough-try_table-argument DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("try_table"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("I32(9)"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later try_table result" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $lhs (result i32) i32.const 1) (func $sink (param i32 i32 i32)) (func (call $sink (call $lhs) (block (result i32) nop unreachable) (try_table (result i32) (i32.const 9)))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-try_table-result suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("i32.const I32(9)"), msg=pretty)
  assert_false(pretty.contains("try_table"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination preserves nonfallthrough try_table before explicit cut" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (type $ft (func)) (type $array (array i8)) (tag $tag (type $ft)) (func (result f64) (block (try_table (result (ref null $array)) unreachable) unreachable) unreachable))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected DCE to preserve nonfallthrough try_table before explicit cut, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("try_table"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later unreachable" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $lhs (result i32) i32.const 1) (func $sink (param i32 i32 i32)) (func (call $sink (call $lhs) (block (result i32) nop unreachable) (unreachable))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-later-unreachable DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination drops stale prefix before explicit unreachable suffix cut" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (block (result f64) i32.const 7 unreachable unreachable) unreachable))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected explicit-unreachable suffix DCE stack cleanup success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32.const I32(7)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "dead-code-elimination voidifies branchless value control before explicit unreachable suffix cut" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result v128) (block (result f64) (v128.const i32x4 1 2 3 4) i32x4.trunc_sat_f64x2_s_zero unreachable unreachable) unreachable))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected explicit-unreachable suffix DCE to voidify branchless value control, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("i32x4.trunc_sat_f64x2s_zero"), msg=pretty)
  assert_true(pretty.contains("v128.const"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_true(pretty.contains("block (Void)"), msg=pretty)
  assert_false(pretty.contains("block F64"), msg=pretty)
}

///|
test "dead-code-elimination voidifies nested nonfallthrough control before explicit cut" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) nop call 0 if (result i32) loop (result i32) i32.const 7 return_call 0 return_call 0 unreachable unreachable end else unreachable end))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected DCE to voidify nested nonfallthrough control before explicit cut, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("nop"), msg=pretty)
  assert_true(pretty.contains("if (Void)"), msg=pretty)
  assert_true(pretty.contains("loop (Void)"), msg=pretty)
  assert_true(pretty.contains("return_call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("if I32"), msg=pretty)
  assert_false(pretty.contains("loop I32"), msg=pretty)
}

///|
test "dead-code-elimination drops stale stack before atomic fence boundary" {
  let mod_ = dead_code_elimination_test_gc_branch_module([], [
    @lib.Instruction::ref_null(@lib.HeapType::abs(@lib.AbsHeapType::no_func())),
    @lib.Instruction::atomic_fence(),
    @lib.Instruction::unreachable_(),
    @lib.Instruction::unreachable_(),
  ])
  let pretty = dead_code_elimination_test_run_gc_branch_pretty(mod_)
  let drop_idx = match dead_code_elimination_test_index_of(pretty, "drop") {
    Some(idx) => idx
    None => fail("expected stale ref.null drop before atomic.fence: \{pretty}")
  }
  let fence_idx = match
    dead_code_elimination_test_index_of(pretty, "atomic.fence") {
    Some(idx) => idx
    None => fail("expected atomic.fence to be preserved: \{pretty}")
  }
  assert_true(drop_idx < fence_idx, msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "dead-code-elimination drops stale stack before data drop boundary" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (data \"\") (func (result i32) i32.const 7 i64.const 8 i32.const 9 data.drop 0 i32.eqz unreachable unreachable))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected DCE to drop stale stack before data.drop boundary, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  let drop_idx = match dead_code_elimination_test_index_of(pretty, "drop") {
    Some(idx) => idx
    None => fail("expected stale prefix drops before data.drop: \{pretty}")
  }
  let data_drop_idx = match
    dead_code_elimination_test_index_of(pretty, "data.drop") {
    Some(idx) => idx
    None => fail("expected data.drop to be preserved: \{pretty}")
  }
  assert_true(drop_idx < data_drop_idx, msg=pretty)
  assert_true(pretty.contains("i32.eqz"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "dead-code-elimination removes nested drops around explicit unreachable cut" {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (rec
        #|    (type $array (sub (array i32)))
        #|    (type $pair (func (result (ref null $array) i32))))
        #|  (func
        #|    (block (type $pair)
        #|      (block
        #|        nop)
        #|      unreachable)
        #|    unreachable))
        #|
      ),
      ["dead-code-elimination"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected DCE to remove nested drops around explicit unreachable cut, got \{err}",
      )
  }
  assert_false(
    trace.any(fn(line) {
      line.contains("legacy-synthetic-try-reachable-arm-dce-noop")
    }),
    msg=trace.to_string(),
  )
  assert_true(
    trace.any(fn(line) { line.contains("dce-explicit-dead-suffix") }),
    msg=trace.to_string(),
  )
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("nop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
}

///|
test "dead-code-elimination preserves multi-instruction if condition while dropping unrelated prefix before branchless if nonfallthrough operand" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $lhs (result i32) i32.const 7) (func $sink (param i32 i32)) (func (call $sink (call $lhs) (if (result i32) (i32.add (i32.const 1) (i32.const 0)) (then unreachable) (else unreachable)))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected branchless-if nonfallthrough DCE stack cleanup success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("if"), msg=pretty)
  assert_true(pretty.contains("i32.add"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later nop" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $lhs (result i32) i32.const 1) (func $sink (param i32 i32 i32)) (func (call $sink (call $lhs) (block (result i32) nop unreachable) (nop) (i32.add (i32.const 2) (i32.const 3)))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-nop suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later load" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func $lhs (result i32) i32.const 1) (func $sink (param i32 i32 i32)) (func (call $sink (call $lhs) (block (result i32) nop unreachable) (i32.load (i32.const 0)))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-load suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("i32.load"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later struct.get" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (type $struct (struct (field i32))) (func $lhs (result i32) i32.const 1) (func $sink (param i32 i32 i32)) (func (call $sink (call $lhs) (block (result i32) nop unreachable) (struct.get $struct 0 (ref.null $struct)))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-struct-get suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("struct.get"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later i31.get" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $lhs (result i32) i32.const 1) (func $sink (param i32 i32 i32)) (func (call $sink (call $lhs) (block (result i32) nop unreachable) (i31.get_s (ref.i31 (i32.const 31))))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-i31-get suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("i31.get"), msg=pretty)
  assert_false(pretty.contains("ref.i31"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later string.new" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (type $bytes (array i8))
        #|  (func $lhs (result i32) i32.const 1)
        #|  (func $sink (param i32 i32 stringref))
        #|  (func
        #|    (call $sink
        #|      (call $lhs)
        #|      (block (result i32) nop unreachable)
        #|      (string.new_utf8_array (ref.null $bytes) (i32.const 0) (i32.const 0)))))
      ),
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-string-new suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("string.new_utf8_array"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later string.encode" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (type $bytes (array (mut i8)))
        #|  (func $lhs (result i32) i32.const 1)
        #|  (func $sink (param i32 i32 i32))
        #|  (func
        #|    (call $sink
        #|      (call $lhs)
        #|      (block (result i32) nop unreachable)
        #|      (string.encode_utf8_array
        #|        (string.const "abc")
        #|        (array.new_default $bytes (i32.const 3))
        #|        (i32.const 0)))))
      ),
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-string-encode suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("string.encode_utf8_array"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later saturating conversion" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $lhs (result i32) i32.const 1) (func $sink (param i32 i32 i32)) (func (call $sink (call $lhs) (block (result i32) nop unreachable) (i32.trunc_sat_f32_s (f32.const 1)))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-saturating-conversion suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("trunc_sat"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later gc mutator" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let lhs_type_idx = @lib.TypeIdx::new(1U)
  let sink_type_idx = @lib.TypeIdx::new(2U)
  let main_type_idx = @lib.TypeIdx::new(3U)
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        array_type,
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
              [],
            ),
          ),
        ),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([lhs_type_idx, sink_type_idx, main_type_idx]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([@lib.Instruction::i32_const(1)]),
        ),
        @lib.Func::new(@lib.Locals::from_types([]), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::nop(),
                @lib.Instruction::unreachable_(),
              ]),
            ),
            @lib.Instruction::i32_const(2),
            @lib.Instruction::array_new_default(array_type_idx),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(7),
            @lib.Instruction::i32_const(1),
            @lib.Instruction::array_fill(array_type_idx),
            @lib.Instruction::i32_const(2),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-gc-mutator suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("array.fill"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later struct.new" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (type $box (struct (field i32) (field i64)))
        #|  (func $lhs (result i32) i32.const 1)
        #|  (func $sink (param i32 i32 eqref))
        #|  (func
        #|    (call $sink
        #|      (call $lhs)
        #|      (block (result i32) nop unreachable)
        #|      (struct.new $box (i32.const 7) (i64.const 8)))))
      ),
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-struct-new suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("struct.new"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later array.new_fixed" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (type $items (array (mut i32)))
        #|  (func $lhs (result i32) i32.const 1)
        #|  (func $sink (param i32 i32 eqref))
        #|  (func
        #|    (call $sink
        #|      (call $lhs)
        #|      (block (result i32) nop unreachable)
        #|      (array.new_fixed $items 2 (i32.const 7) (i32.const 8)))))
      ),
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-array-new-fixed suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("array.new_fixed"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later struct.new_default" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (type $box (struct (field i32)))
        #|  (func $lhs (result i32) i32.const 1)
        #|  (func $sink (param i32 i32 eqref))
        #|  (func
        #|    (call $sink
        #|      (call $lhs)
        #|      (block (result i32) nop unreachable)
        #|      (struct.new_default $box))))
      ),
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-struct-new-default suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("struct.new_default"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later array.new_data" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (type $items (array (mut i8)))
        #|  (data $payload "abc")
        #|  (func $lhs (result i32) i32.const 1)
        #|  (func $sink (param i32 i32 eqref))
        #|  (func
        #|    (call $sink
        #|      (call $lhs)
        #|      (block (result i32) nop unreachable)
        #|      (array.new_data $items $payload (i32.const 0) (i32.const 2)))))
      ),
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-array-new-data suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("array.new_data"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later struct.new_default_desc" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (rec
        #|    (type $box (descriptor $box_desc) (struct))
        #|    (type $box_desc (describes $box) (struct)))
        #|  (func $lhs (result i32) i32.const 1)
        #|  (func $sink (param i32 i32 eqref))
        #|  (func
        #|    (call $sink
        #|      (call $lhs)
        #|      (block (result i32) nop unreachable)
        #|      (struct.new_default_desc $box (ref.null (exact $box_desc))))))
      ),
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-struct-new-default-desc suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("struct.new_default_desc"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later array.get" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let lhs_type_idx = @lib.TypeIdx::new(1U)
  let sink_type_idx = @lib.TypeIdx::new(2U)
  let main_type_idx = @lib.TypeIdx::new(3U)
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        array_type,
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
              [],
            ),
          ),
        ),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([lhs_type_idx, sink_type_idx, main_type_idx]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([@lib.Instruction::i32_const(1)]),
        ),
        @lib.Func::new(@lib.Locals::from_types([]), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::nop(),
                @lib.Instruction::unreachable_(),
              ]),
            ),
            @lib.Instruction::ref_null(@lib.HeapType::new(array_type_idx)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::array_get(array_type_idx),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-array-get suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("array.get"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later array.len" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let lhs_type_idx = @lib.TypeIdx::new(1U)
  let sink_type_idx = @lib.TypeIdx::new(2U)
  let main_type_idx = @lib.TypeIdx::new(3U)
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        array_type,
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
              [],
            ),
          ),
        ),
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(
      @lib.FuncSec::new([lhs_type_idx, sink_type_idx, main_type_idx]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([@lib.Instruction::i32_const(1)]),
        ),
        @lib.Func::new(@lib.Locals::from_types([]), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::call(@lib.FuncIdx::new(0U)),
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([
                @lib.Instruction::nop(),
                @lib.Instruction::unreachable_(),
              ]),
            ),
            @lib.Instruction::ref_null(@lib.HeapType::new(array_type_idx)),
            @lib.Instruction::array_len(),
            @lib.Instruction::call(@lib.FuncIdx::new(1U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-array-len suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("array.len"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later simd splat" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $lhs (result i32) i32.const 1) (func $sink (param i32 i32 v128)) (func (call $sink (call $lhs) (block (result i32) nop unreachable) (i8x16.splat (i32.const 7)))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-simd-splat suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("i8x16.splat"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later simd binary" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $lhs (result i32) i32.const 1) (func $sink (param i32 i32 v128)) (func (call $sink (call $lhs) (block (result i32) nop unreachable) (i8x16.add (i8x16.splat (i32.const 1)) (i8x16.splat (i32.const 2))))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-simd-binary suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("i8x16.add"), msg=pretty)
  assert_false(pretty.contains("i8x16.splat"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
fn dce_test_atomic_suffix_module(
  suffix : Array[@lib.Instruction],
) -> @lib.Module {
  let body = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::block(
      @lib.BlockType::val_type(@lib.ValType::i32()),
      @lib.Expr::new([@lib.Instruction::nop(), @lib.Instruction::unreachable_()]),
    ),
  ]
  suffix.each(fn(instr) { body.push(instr) })
  body.push(@lib.Instruction::call(@lib.FuncIdx::new(1U)))
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func([], [@lib.ValType::i32()])),
      ),
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func(
            [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
            [],
          ),
        ),
      ),
      @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
    ]),
  )
  .with_func_sec(
    @lib.FuncSec::new([
      @lib.TypeIdx::new(0U),
      @lib.TypeIdx::new(1U),
      @lib.TypeIdx::new(2U),
    ]),
  )
  .with_mem_sec(
    @lib.MemSec::new([
      @lib.MemType::new(@lib.Limits::i32(1U, Some(1U)), shared=true),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([]),
        @lib.Expr::new([@lib.Instruction::i32_const(1)]),
      ),
      @lib.Func::new(@lib.Locals::from_types([]), @lib.Expr::new([])),
      @lib.Func::new(@lib.Locals::from_types([]), @lib.Expr::new(body)),
    ]),
  )
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later atomic load" {
  let input = dce_test_atomic_suffix_module([
    @lib.Instruction::i32_const(0),
    @lib.Instruction::i32_atomic_load(@lib.MemArg::new(2U, None, 0UL)),
  ])
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-atomic-load suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("atomic.load"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later atomic rmw" {
  let input = dce_test_atomic_suffix_module([
    @lib.Instruction::i32_const(0),
    @lib.Instruction::i32_const(1),
    @lib.Instruction::atomic_rmw(
      @lib.AtomicRmwOp::i32_add(),
      @lib.MemArg::new(2U, None, 0UL),
    ),
  ])
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-atomic-rmw suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("AtomicRmw"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later atomic cmpxchg" {
  let input = dce_test_atomic_suffix_module([
    @lib.Instruction::i32_const(0),
    @lib.Instruction::i32_const(1),
    @lib.Instruction::i32_const(2),
    @lib.Instruction::atomic_cmpxchg(
      @lib.AtomicCmpxchgOp::i32(),
      @lib.MemArg::new(2U, None, 0UL),
    ),
  ])
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-atomic-cmpxchg suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("AtomicCmpxchg"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later table.get" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (table 1 externref) (func $lhs (result i32) i32.const 1) (func $sink (param i32 i32 externref)) (func (call $sink (call $lhs) (block (result i32) nop unreachable) (table.get (i32.const 0)))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-table-get suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("table.get"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later memory.size" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func $lhs (result i32) i32.const 1) (func $sink (param i32 i32 i32)) (func (call $sink (call $lhs) (block (result i32) nop unreachable) (memory.size))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-memory-size suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("memory.size"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later memory.grow" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (memory 1) (func $lhs (result i32) i32.const 1) (func $sink (param i32 i32 i32)) (func (call $sink (call $lhs) (block (result i32) nop unreachable) (memory.grow (i32.const 1)))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-memory-grow suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("memory.grow"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later table.size" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (table 1 externref) (func $lhs (result i32) i32.const 1) (func $sink (param i32 i32 i32)) (func (call $sink (call $lhs) (block (result i32) nop unreachable) (table.size))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-table-size suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("table.size"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later table.grow" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (table 1 externref) (func $lhs (result i32) i32.const 1) (func $sink (param i32 i32 i32)) (func (call $sink (call $lhs) (block (result i32) nop unreachable) (table.grow (ref.null extern) (i32.const 1)))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-table-grow suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("table.grow"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims dead table.fill suffix after unreachable call argument" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (table 1 externref) (func $lhs (result i32) i32.const 1) (func $sink (param i32 i32)) (func (call $sink (call $lhs) (block (result i32) nop unreachable)) (table.fill (i32.const 0) (ref.null extern) (i32.const 1))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-table-fill suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("table.fill"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later local.get" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $lhs (result i32) i32.const 1) (func $sink (param i32 i32 i32)) (func (local i32) (local.set 0 (i32.const 7)) (call $sink (call $lhs) (block (result i32) nop unreachable) (local.get 0))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-local-get suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("local.get"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later global.get" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (global $g i32 (i32.const 7)) (func $lhs (result i32) i32.const 1) (func $sink (param i32 i32 i32)) (func (call $sink (call $lhs) (block (result i32) nop unreachable) (global.get $g))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-global-get suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("global.get"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination trims direct-call consumer after unreachable argument and dead later ref.eq" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func $lhs (result i32) i32.const 1) (func $sink (param i32 i32 i32)) (func (call $sink (call $lhs) (block (result i32) nop unreachable) (ref.eq (ref.null eq) (ref.null eq)))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call unreachable-argument dead-ref-eq suffix DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("ref.eq"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
}

///|
test "dead-code-elimination preserves evaluated return-call operand before unreachable argument" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (type $sink-type (func (param i32 i32 i32))) (func $lhs (result i32) i32.const 1) (func $rhs (result i32) i32.const 2) (func $sink (type $sink-type)) (func (return_call $sink (call $lhs) (block (result i32) nop unreachable) (call $rhs))))",
      ["dead-code-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected return-call unreachable-argument DCE success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
  assert_false(pretty.contains("return_call"), msg=pretty)
}

///|
test "dead-code-elimination trims return_call_indirect after unreachable argument" {
  let source =
    #|(module
    #|  (type $sink-type (func (param i32 i32 i32)))
    #|  (table 1 funcref)
    #|  (func $lhs (result i32) i32.const 1)
    #|  (func $rhs (result i32) i32.const 2)
    #|  (func $sink (type $sink-type))
    #|  (elem (i32.const 0) $sink)
    #|  (func
    #|    (return_call_indirect (type $sink-type)
    #|      (call $lhs)
    #|      (block (result i32) nop unreachable)
    #|      (call $rhs)
    #|      (i32.const 0))))
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected return_call_indirect unreachable-argument DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
  assert_false(pretty.contains("return_call_indirect"), msg=pretty)
}

///|
test "dead-code-elimination trims return_call_ref after unreachable argument" {
  let source =
    #|(module
    #|  (type $sink-type (func (param i32 i32 i32)))
    #|  (func $lhs (result i32) i32.const 1)
    #|  (func $rhs (result i32) i32.const 2)
    #|  (func $sink (type $sink-type))
    #|  (elem declare func $sink)
    #|  (func
    #|    (return_call_ref (type $sink-type)
    #|      (call $lhs)
    #|      (block (result i32) nop unreachable)
    #|      (call $rhs)
    #|      (ref.func $sink))))
    #|)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected return_call_ref unreachable-argument DCE success, got \{err}",
      )
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(3U))
  assert_true(pretty.contains("call (Func 0)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
  assert_false(pretty.contains("Func 1"), msg=pretty)
  assert_false(pretty.contains("return_call_ref"), msg=pretty)
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
test "dead-code-elimination repairs pop-within-block dead ref-eq text" {
  let source =
    #|(module
    #|  (type $struct (struct (field eqref)))
    #|  (tag $e-eqref (param eqref))
    #|  (func (result i32)
    #|    (try (result i32)
    #|      (do
    #|        i32.const 0)
    #|      (catch $e-eqref
    #|        (drop
    #|          (ref.eq
    #|            (struct.new $struct
    #|              (pop eqref))
    #|            (unreachable)))
    #|        i32.const 0)))
    #|)
    #|
  let input_mod = match @wast.wast_to_binary_module(source) {
    Ok(mod_) => mod_
    Err(err) => fail("expected pop-within-block text lowering success: \{err}")
  }
  match @validate.validate_module(input_mod) {
    Ok(_) => ()
    Err(err) =>
      fail("expected pop-within-block text validation success: \{err}")
  }
  let optimized = match
    run_hot_pipeline(input_mod, HotPipelineOptions::new(), [
      "dead-code-elimination",
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected pop-within-block text DCE pipeline success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("ref.eq"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "dead-code-elimination repairs struct-new pop call arg before branch text" {
  let source =
    #|(module
    #|  (type $box (struct (field i32)))
    #|  (tag $e-i32 (param i32))
    #|  (func
    #|    (block $label
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32
    #|          (call $helper
    #|            (struct.new $box
    #|              (pop i32))
    #|            (br $label))
    #|          nop))))
    #|  (func $helper (param (ref $box) i32)))
    #|)
    #|
  let input_mod = match @wast.wast_to_binary_module(source) {
    Ok(mod_) => mod_
    Err(err) => fail("expected struct-new pop text lowering success: \{err}")
  }
  match @validate.validate_module(input_mod) {
    Ok(_) => ()
    Err(err) => fail("expected struct-new pop text validation success: \{err}")
  }
  let optimized = match
    run_hot_pipeline(input_mod, HotPipelineOptions::new(), [
      "dead-code-elimination",
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected struct-new pop DCE pipeline success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
}

///|
test "dead-code-elimination repairs struct-new pop call arg before return text" {
  let source =
    #|(module
    #|  (type $box (struct (field i32)))
    #|  (tag $e-i32 (param i32))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (struct.new $box
    #|            (pop i32))
    #|          (return))
    #|        nop)))
    #|  (func $helper (param (ref $box) i32)))
    #|)
    #|
  let input_mod = match @wast.wast_to_binary_module(source) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected struct-new return pop text lowering success: \{err}")
  }
  match @validate.validate_module(input_mod) {
    Ok(_) => ()
    Err(err) =>
      fail("expected struct-new return pop text validation success: \{err}")
  }
  let optimized = match
    run_hot_pipeline(input_mod, HotPipelineOptions::new(), [
      "dead-code-elimination",
    ]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected struct-new return pop DCE pipeline success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("return"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
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
test "dead-code-elimination repairs effectful call arg before catch pop branch text" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (tag $e-i32 (param i32))
    #|  (func
    #|    (block $label
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32
    #|          (call $helper
    #|            (i32.load (i32.const 0))
    #|            (pop i32)
    #|            (br $label))
    #|          nop))))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected effectful call-pop DCE pipeline success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs nested call arg before catch pop branch text" {
  let source =
    #|(module
    #|  (tag $e-i32 (param i32))
    #|  (func
    #|    (block $label
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32
    #|          (call $helper
    #|            (block (result i32) (i32.const 7))
    #|            (block (result i32) (pop i32))
    #|            (br $label))
    #|          nop))))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected nested call-pop DCE pipeline success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs global.get call arg before catch pop branch text" {
  let source =
    #|(module
    #|  (global $g i32 (i32.const 7))
    #|  (tag $e-i32 (param i32))
    #|  (func
    #|    (block $label
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32
    #|          (call $helper
    #|            (global.get $g)
    #|            (pop i32)
    #|            (br $label))
    #|          nop))))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected global.get call-pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("global.get"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs unary call arg before catch pop branch text" {
  let source =
    #|(module
    #|  (tag $e-i32 (param i32))
    #|  (func
    #|    (block $label
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32
    #|          (call $helper
    #|            (i32.eqz (i32.const 0))
    #|            (pop i32)
    #|            (br $label))
    #|          nop))))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected unary call-pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("i32.eqz"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs binary call arg before catch pop branch text" {
  let source =
    #|(module
    #|  (tag $e-i32 (param i32))
    #|  (func
    #|    (block $label
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32
    #|          (call $helper
    #|            (i32.add (i32.const 1) (i32.const 2))
    #|            (pop i32)
    #|            (br $label))
    #|          nop))))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected binary call-pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("i32.add"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs side-effect call arg before catch pop branch text" {
  let source =
    #|(module
    #|  (tag $e-i32 (param i32))
    #|  (func $side (result i32) (i32.const 11))
    #|  (func
    #|    (block $label
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32
    #|          (call $helper
    #|            (call $side)
    #|            (pop i32)
    #|            (br $label))
    #|          nop))))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected side-effect call-arg pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs multivalue call arg before catch pop branch text" {
  let source =
    #|(module
    #|  (tag $e-i32 (param i32))
    #|  (func $side (result i32 i64)
    #|    (i32.const 11)
    #|    (i64.const 12))
    #|  (func
    #|    (block $label
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32
    #|          (call $helper
    #|            (call $side)
    #|            (pop i32)
    #|            (br $label))
    #|          nop))))
    #|  (func $helper (param i32 i64 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected multivalue side call-arg pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs indirect call catch pop branch text" {
  let source =
    #|(module
    #|  (type $helper-type (func (param i32 i32)))
    #|  (tag $e-i32 (param i32))
    #|  (table 1 funcref)
    #|  (func $helper (type $helper-type))
    #|  (elem (i32.const 0) $helper)
    #|  (func
    #|    (block $label
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32
    #|          (call_indirect (type $helper-type)
    #|            (pop i32)
    #|            (br $label)
    #|            (i32.const 0))
    #|          nop))))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected indirect call-pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("call_indirect"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs indirect call arg before catch pop branch text" {
  let source =
    #|(module
    #|  (type $side-type (func (result i32)))
    #|  (tag $e-i32 (param i32))
    #|  (table 1 funcref)
    #|  (func $side (type $side-type) (i32.const 11))
    #|  (elem (i32.const 0) $side)
    #|  (func
    #|    (block $label
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32
    #|          (call $helper
    #|            (call_indirect (type $side-type) (i32.const 0))
    #|            (pop i32)
    #|            (br $label))
    #|          nop))))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected indirect call-arg pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call_indirect"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs call_ref catch pop branch text" {
  let source =
    #|(module
    #|  (type $helper-type (func (param i32 i32)))
    #|  (tag $e-i32 (param i32))
    #|  (func $helper (type $helper-type))
    #|  (elem declare func $helper)
    #|  (func
    #|    (block $label
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32
    #|          (call_ref (type $helper-type)
    #|            (pop i32)
    #|            (br $label)
    #|            (ref.func $helper))
    #|          nop))))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected call_ref pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_false(pretty.contains("call_ref"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs call_ref arg before catch pop branch text" {
  let source =
    #|(module
    #|  (type $side-type (func (result i32)))
    #|  (tag $e-i32 (param i32))
    #|  (func $side (type $side-type) (i32.const 11))
    #|  (elem declare func $side)
    #|  (func
    #|    (block $label
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32
    #|          (call $helper
    #|            (call_ref (type $side-type) (ref.func $side))
    #|            (pop i32)
    #|            (br $label))
    #|          nop))))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected call_ref call-arg pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("call_ref"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs catch pop before tail call text" {
  let source =
    #|(module
    #|  (tag $e-i32 (param i32))
    #|  (func $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (pop i32)
    #|        (return_call $tail)
    #|        nop)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected tail-call pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs dead call arg before catch pop tail call text" {
  let source =
    #|(module
    #|  (tag $e-i32 (param i32))
    #|  (func $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (pop i32)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected dead-call tail-call pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs const arg before catch pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (func $tail (type $tail-type) (param i32))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (i32.const 7)
    #|          (pop i32)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected const-arg parameterized tail-call pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs const arg before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (call $helper
    #|          (i32.const 7)
    #|          (pop i32)
    #|          (pop i64)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected const-arg multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(3)"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs unary arg before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (call $helper
    #|          (i32.const 0)
    #|          (i32.eqz)
    #|          (pop i32)
    #|          (pop i64)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected unary-arg multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(3)"), msg=pretty)
  assert_true(pretty.contains("i32.eqz"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs conversion arg before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        i32.const 11
    #|        i64.extend_i32_s
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i64 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected conversion-arg multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(3)"), msg=pretty)
  assert_true(pretty.contains("i64.extend_i32"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs local tee arg before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (local i32)
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        i32.const 17
    #|        local.tee 0
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected local-tee-arg multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(3)"), msg=pretty)
  assert_true(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs call_indirect arg before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $producer-type (func (result i32)))
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (table 1 funcref)
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        i32.const 0
    #|        call_indirect (type $producer-type)
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected call_indirect-arg multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("call_indirect"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs call_ref arg before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $producer-type (func (result i32)))
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $producer (type $producer-type) (i32.const 31))
    #|  (elem declare func $producer)
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        ref.func $producer
    #|        call_ref (type $producer-type)
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(2U),
  )
  assert_true(before.contains("call (Func 3)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected call_ref-arg multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(3)"), msg=pretty)
  assert_true(pretty.contains("call_ref"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs multi-param call_indirect arg before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $producer-type (func (param i32 i64) (result i32)))
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (table 1 funcref)
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        i32.const 17
    #|        i64.const 19
    #|        i32.const 0
    #|        call_indirect (type $producer-type)
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected multi-param call_indirect-arg multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("call_indirect"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs multi-param call_ref arg before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $producer-type (func (param i32 i64) (result i32)))
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $producer (type $producer-type) (i32.const 31))
    #|  (elem declare func $producer)
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        i32.const 17
    #|        i64.const 19
    #|        ref.func $producer
    #|        call_ref (type $producer-type)
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(2U),
  )
  assert_true(before.contains("call (Func 3)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected multi-param call_ref-arg multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(3)"), msg=pretty)
  assert_true(pretty.contains("call_ref"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs multi-param direct call arg before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $producer-type (func (param i32 i64) (result i32)))
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        i32.const 17
    #|        i64.const 19
    #|        call $producer
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $producer (type $producer-type) (param i32 i64) (result i32)
    #|    (local.get 0))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected multi-param direct-call-arg multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(3)"), msg=pretty)
  assert_true(pretty.contains("call (Func 2)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs multi-result direct call before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $producer-type (func (result i32 i64)))
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        call $producer
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $producer (type $producer-type) (result i32 i64)
    #|    (i32.const 17)
    #|    (i64.const 19))
    #|  (func $helper (param i32 i64 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected multi-result direct-call multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(3)"), msg=pretty)
  assert_true(pretty.contains("call (Func 2)"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs multi-result call_indirect before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $producer-type (func (result i32 i64)))
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (table 1 funcref)
    #|  (func $tail (type $tail-type) (param i32 i64))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        i32.const 0
    #|        call_indirect (type $producer-type)
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 i64 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected multi-result call_indirect multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("call_indirect"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs multi-result call_ref before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $producer-type (func (result i32 i64)))
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $producer (type $producer-type) (result i32 i64)
    #|    (i32.const 17)
    #|    (i64.const 19))
    #|  (elem declare func $producer)
    #|  (func $tail (type $tail-type) (param i32 i64))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        ref.func $producer
    #|        call_ref (type $producer-type)
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 i64 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(2U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected multi-result call_ref multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(3)"), msg=pretty)
  assert_true(pretty.contains("call_ref"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs select prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        i32.const 17
    #|        i32.const 19
    #|        i32.const 1
    #|        select
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("select"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected select-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs ref.is_null prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        ref.null extern
    #|        ref.is_null
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref.is_null-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs ref.eq prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        ref.null eq
    #|        ref.null eq
    #|        ref.eq
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("ref.eq"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref.eq-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("ref.eq"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs ref.as_non_null prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param externref i64)))
    #|  (tag $e-i64-extern (param i64 externref))
    #|  (func $tail (type $tail-type) (param externref i64))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-extern
    #|        ref.null extern
    #|        ref.as_non_null
    #|        pop externref
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 externref i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("ref.as_non_null"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref.as_non_null-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("ref.as_non_null"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs table.get prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param funcref i64)))
    #|  (tag $e-i64-func (param i64 funcref))
    #|  (table 1 funcref)
    #|  (func $tail (type $tail-type) (param funcref i64))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-func
    #|        i32.const 0
    #|        table.get 0
    #|        pop funcref
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 funcref i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("table.get"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table.get-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("table.get"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs string.const prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param stringref i64)))
    #|  (tag $e-i64-string (param i64 stringref))
    #|  (func $tail (type $tail-type) (param stringref i64))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-string
    #|        string.const "dead-prefix"
    #|        pop stringref
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param stringref stringref i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("string.const"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected string.const-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("string.const"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs string.new_utf8_array prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $bytes (array i8))
    #|  (type $tail-type (func (param stringref i64)))
    #|  (tag $e-i64-string (param i64 stringref))
    #|  (func $tail (type $tail-type) (param stringref i64))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-string
    #|        ref.null $bytes
    #|        i32.const 0
    #|        i32.const 0
    #|        string.new_utf8_array
    #|        pop stringref
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 stringref i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("string.new_utf8_array"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected string.new_utf8_array-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("string.new_utf8_array"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs string.encode_utf8_array prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $bytes (array (mut i8)))
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        string.const "abc"
    #|        i32.const 8
    #|        array.new_default $bytes
    #|        i32.const 0
    #|        string.encode_utf8_array
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("string.encode_utf8_array"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected string.encode_utf8_array-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("string.encode_utf8_array"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs string.encode_wtf16_array prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $words (array (mut i16)))
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        string.const "abc"
    #|        i32.const 8
    #|        array.new_default $words
    #|        i32.const 0
    #|        string.encode_wtf16_array
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("string.encode_wtf16_array"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected string.encode_wtf16_array-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("string.encode_wtf16_array"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs string.encode_lossy_utf8_array prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $bytes (array (mut i8)))
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        string.const "abc"
    #|        i32.const 8
    #|        array.new_default $bytes
    #|        i32.const 0
    #|        string.encode_lossy_utf8_array
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("string.encode_lossy_utf8_array"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected string.encode_lossy_utf8_array-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("string.encode_lossy_utf8_array"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs string.encode_wtf8_array prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $bytes (array (mut i8)))
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        string.const "abc"
    #|        i32.const 8
    #|        array.new_default $bytes
    #|        i32.const 0
    #|        string.encode_wtf8_array
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("string.encode_wtf8_array"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected string.encode_wtf8_array-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("string.encode_wtf8_array"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs table.size prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (table 1 funcref)
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (call $helper
    #|          (table.size)
    #|          (pop i32)
    #|          (pop i64)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("table.size"), msg=before)
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table.size prefix parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("table.size"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs table.grow prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (table 1 funcref)
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (call $helper
    #|          (ref.null func)
    #|          (i32.const 1)
    #|          (table.grow)
    #|          (pop i32)
    #|          (pop i64)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("table.grow"), msg=before)
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table.grow prefix parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("table.grow"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs table.set prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (table 1 funcref)
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (call $helper
    #|          (i32.const 0)
    #|          (ref.null func)
    #|          (table.set)
    #|          (i32.const 13)
    #|          (pop i32)
    #|          (pop i64)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("table.set"), msg=before)
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table.set prefix parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("table.set"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs global.set prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (global $g (mut i32) (i32.const 0))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (call $helper
    #|          (i32.const 11)
    #|          (global.set $g)
    #|          (i32.const 13)
    #|          (pop i32)
    #|          (pop i64)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("global.set"), msg=before)
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected global.set prefix parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("global.set"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs table.fill prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (table 2 funcref)
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (call $helper
    #|          (i32.const 0)
    #|          (ref.null func)
    #|          (i32.const 1)
    #|          (table.fill)
    #|          (i32.const 17)
    #|          (pop i32)
    #|          (pop i64)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("table.fill"), msg=before)
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table.fill prefix parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("table.fill"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs table.copy prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (table 4 funcref)
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (call $helper
    #|          (i32.const 0)
    #|          (i32.const 1)
    #|          (i32.const 1)
    #|          (table.copy)
    #|          (i32.const 19)
    #|          (pop i32)
    #|          (pop i64)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("table.copy"), msg=before)
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table.copy prefix parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("table.copy"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs table.init prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (table 4 funcref)
    #|  (elem $e func $tail)
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (call $helper
    #|          (i32.const 0)
    #|          (i32.const 0)
    #|          (i32.const 1)
    #|          (table.init $e)
    #|          (i32.const 23)
    #|          (pop i32)
    #|          (pop i64)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("table.init"), msg=before)
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected table.init prefix parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("table.init"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs memory.size prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (memory 1)
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (call $helper
    #|          (memory.size)
    #|          (pop i32)
    #|          (pop i64)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("memory.size"), msg=before)
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory.size prefix parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("memory.size"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs memory.grow prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (memory 1)
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (call $helper
    #|          (i32.const 1)
    #|          (memory.grow)
    #|          (pop i32)
    #|          (pop i64)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("memory.grow"), msg=before)
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory.grow prefix parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("memory.grow"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs i32.store prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (memory 1)
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (call $helper
    #|          (i32.const 0)
    #|          (i32.const 11)
    #|          (i32.store)
    #|          (i32.const 41)
    #|          (pop i32)
    #|          (pop i64)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("i32.store"), msg=before)
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected i32.store prefix parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("i32.store"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs f64.store prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (memory 1)
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (call $helper
    #|          (i32.const 8)
    #|          (f64.const 1.5)
    #|          (f64.store)
    #|          (i32.const 43)
    #|          (pop i32)
    #|          (pop i64)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("f64.store"), msg=before)
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected f64.store prefix parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("f64.store"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs memory.fill prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (memory 1)
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (call $helper
    #|          (i32.const 0)
    #|          (i32.const 7)
    #|          (i32.const 1)
    #|          (memory.fill)
    #|          (i32.const 29)
    #|          (pop i32)
    #|          (pop i64)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("memory.fill"), msg=before)
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory.fill prefix parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("memory.fill"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs memory.copy prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (memory 1)
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (call $helper
    #|          (i32.const 0)
    #|          (i32.const 1)
    #|          (i32.const 1)
    #|          (memory.copy)
    #|          (i32.const 31)
    #|          (pop i32)
    #|          (pop i64)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("memory.copy"), msg=before)
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory.copy prefix parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("memory.copy"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs memory.init prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (memory 1)
    #|  (data $d "x")
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (call $helper
    #|          (i32.const 0)
    #|          (i32.const 0)
    #|          (i32.const 1)
    #|          (memory.init $d)
    #|          (i32.const 37)
    #|          (pop i32)
    #|          (pop i64)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("memory.init"), msg=before)
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected memory.init prefix parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("memory.init"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs array.new_default prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $items (array i32))
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64)
    #|    (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        i32.const 1
    #|        array.new_default $items
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("array.new_default"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected array.new_default-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("array.new_default"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs array.new prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $items (array i32))
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64)
    #|    (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        i32.const 7
    #|        i32.const 1
    #|        array.new $items
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("array.new"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected array.new-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("array.new"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs array.new_fixed prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $items (array i32))
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64)
    #|    (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        i32.const 7
    #|        i32.const 8
    #|        array.new_fixed $items 2
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("array.new_fixed"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected array.new_fixed-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("array.new_fixed"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs array.new_data prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $items (array (mut i8)))
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (data $payload "abcd")
    #|  (func $tail (type $tail-type) (param i32 i64)
    #|    (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        i32.const 1
    #|        i32.const 2
    #|        array.new_data $items $payload
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("array.new_data"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected array.new_data-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("array.new_data"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs array.new_elem prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $items (array funcref))
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $elem_target)
    #|  (elem $payload func $elem_target)
    #|  (func $tail (type $tail-type) (param i32 i64)
    #|    (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        i32.const 0
    #|        i32.const 1
    #|        array.new_elem $items $payload
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(2U),
  )
  assert_true(before.contains("array.new_elem"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected array.new_elem-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(3)"), msg=pretty)
  assert_true(pretty.contains("array.new_elem"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs struct.new_default prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $box (struct (field i32)))
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64)
    #|    (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        struct.new_default $box
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("struct.new_default"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected struct.new_default-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("struct.new_default"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs struct.new prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $box (struct (field i32) (field i64)))
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64)
    #|    (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        i32.const 7
    #|        i64.const 8
    #|        struct.new $box
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("struct.new"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected struct.new-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("struct.new"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs struct.new_desc prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (rec
    #|    (type $box
    #|      (descriptor $box_desc)
    #|      (struct))
    #|    (type $box_desc
    #|      (describes $box)
    #|      (struct)))
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64)
    #|    (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (struct.new_desc $box
    #|          (ref.null (exact $box_desc)))
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("struct.new_desc"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected struct.new_desc-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("struct.new_desc"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs struct.new_default_desc prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (rec
    #|    (type $box
    #|      (descriptor $box_desc)
    #|      (struct))
    #|    (type $box_desc
    #|      (describes $box)
    #|      (struct)))
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64)
    #|    (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (struct.new_default_desc $box
    #|          (ref.null (exact $box_desc)))
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("struct.new_default_desc"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected struct.new_default_desc-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("struct.new_default_desc"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs any.convert_extern prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64)
    #|    (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        ref.null extern
    #|        any.convert_extern
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper))
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("any.convert_extern"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected any.convert_extern-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("any.convert_extern"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs extern.convert_any prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64)
    #|    (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        ref.null any
    #|        extern.convert_any
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper))
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("extern.convert_any"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected extern.convert_any-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("extern.convert_any"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs ref.i31 prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64)
    #|    (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        i32.const 7
    #|        ref.i31
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper))
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("ref.i31"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref.i31-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("ref.i31"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs i31.get_s prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64)
    #|    (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        i32.const 7
    #|        ref.i31
    #|        i31.get_s
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper))
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("i31.get_s"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected i31.get_s-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("i31.get_s"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs i31.get_u prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64)
    #|    (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        i32.const 7
    #|        ref.i31
    #|        i31.get_u
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper))
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("i31.get_u"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected i31.get_u-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("i31.get_u"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs struct.get prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $struct (struct (field i32)))
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        ref.null $struct
    #|        struct.get $struct 0
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("struct.get"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected struct.get-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("struct.get"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs ref.get_desc prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (rec
    #|    (type $node (descriptor $node_desc) (struct))
    #|    (type $node_desc (describes $node) (struct))
    #|  )
    #|  (type $tail-type (func (param anyref i64)))
    #|  (tag $e-i64-desc (param i64 anyref))
    #|  (func $tail (type $tail-type) (param anyref i64))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-desc
    #|        ref.null $node
    #|        ref.get_desc $node
    #|        pop anyref
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 anyref i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("ref.get_desc"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref.get_desc-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("ref.get_desc"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs ref.test_desc prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        ref.null func
    #|        ref.test_desc 0
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("ref.test_desc"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref.test_desc-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("ref.test_desc"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs ref.cast_desc_eq prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param funcref i64)))
    #|  (tag $e-i64-func (param i64 funcref))
    #|  (func $tail (type $tail-type) (param funcref i64))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-func
    #|        ref.null func
    #|        ref.cast_desc_eq_null 0
    #|        pop funcref
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 funcref i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("ref.cast_desc_eq"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected ref.cast_desc_eq-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("ref.cast_desc_eq"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs typed select prefix before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (param i32 i64))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        i32.const 17
    #|        i32.const 19
    #|        i32.const 1
    #|        select (result i32)
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("select"), msg=before)
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected typed-select-prefix multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("select"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "drop"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs nop-prefixed const arg before catch multi-pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        nop
    #|        i32.const 23
    #|        pop i32
    #|        pop i64
    #|        return_call $tail
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 i32 i64)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nop-prefixed const multi-pop parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(3)"), msg=pretty)
  assert_true(pretty.contains("nop"), msg=pretty)
  assert_true(pretty.contains("I32(23)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs nop-prefixed const arg before catch multi-pop parameterized return_call_ref text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (elem declare func $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        nop
    #|        i32.const 29
    #|        pop i32
    #|        pop i64
    #|        ref.func $tail
    #|        return_call_ref (type $tail-type)
    #|        call $helper
    #|        nop)))
    #|  (func $helper (param i32 i32 i64 funcref)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected nop-prefixed const multi-pop parameterized return_call_ref pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_ref"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(3)"), msg=pretty)
  assert_true(pretty.contains("nop"), msg=pretty)
  assert_true(pretty.contains("I32(29)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs direct call arg before catch pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (func $tail (type $tail-type) (param i32))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (call $producer)
    #|          (pop i32)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $producer (result i32) (i32.const 13))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call-arg parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_true(pretty.contains("call (Func 2)"), msg=pretty)
  assert_false(pretty.contains("call (Func 3)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs block-result arg before catch pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (func $tail (type $tail-type) (param i32))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (block (result i32) (i32.const 11))
    #|          (pop i32)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected block-result-arg parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("block I32"), msg=pretty)
  assert_true(pretty.contains("I32(11)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs binary arg before catch pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (func $tail (type $tail-type) (param i32))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (i32.add (i32.const 1) (i32.const 2))
    #|          (pop i32)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected binary-arg parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("i32.add"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs non-add binary arg before catch pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (func $tail (type $tail-type) (param i32))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (i32.sub (i32.const 9) (i32.const 4))
    #|          (pop i32)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected non-add-binary parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("i32.sub"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs unary arg before catch pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (func $tail (type $tail-type) (param i32))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (i32.eqz (i32.const 0))
    #|          (pop i32)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected unary-arg parameterized tail-call pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("i32.eqz"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs loop-result arg before catch pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (func $tail (type $tail-type) (param i32))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (loop (result i32) (i32.const 12))
    #|          (pop i32)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected loop-result-arg parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("loop I32"), msg=pretty)
  assert_true(pretty.contains("I32(12)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs evaluated arg before catch pop parameterized tail call text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (memory 1)
    #|  (tag $e-i32 (param i32))
    #|  (func $tail (type $tail-type) (param i32))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (i32.load (i32.const 0))
    #|          (pop i32)
    #|          (return_call $tail))
    #|        nop)))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected evaluated-arg parameterized tail-call pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs const arg before catch pop parameterized return_call_indirect text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (table 1 funcref)
    #|  (func $tail (type $tail-type) (param i32))
    #|  (elem (i32.const 0) $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (i32.const 7)
    #|          (pop i32)
    #|          (i32.const 0)
    #|          (return_call_indirect (type $tail-type)))
    #|        nop)))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected const-arg parameterized return_call_indirect pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_indirect"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs const arg before catch multi-pop parameterized return_call_indirect text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (table 1 funcref)
    #|  (elem (i32.const 0) $tail)
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (call $helper
    #|          (i32.const 7)
    #|          (pop i32)
    #|          (pop i64)
    #|          (i32.const 0)
    #|          (return_call_indirect (type $tail-type)))
    #|        nop)))
    #|  (func $helper (param i32 i32 i64 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected const-arg multi-pop parameterized return_call_indirect pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_indirect"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(3)"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs load arg before catch multi-pop parameterized return_call_indirect text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (memory 1)
    #|  (table 1 funcref)
    #|  (elem (i32.const 0) $tail)
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (call $helper
    #|          (i32.const 0)
    #|          (i32.load)
    #|          (pop i32)
    #|          (pop i64)
    #|          (i32.const 0)
    #|          (return_call_indirect (type $tail-type)))
    #|        nop)))
    #|  (func $helper (param i32 i32 i64 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected load-arg multi-pop parameterized return_call_indirect pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_indirect"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(3)"), msg=pretty)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs block-result arg before catch pop parameterized return_call_indirect text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (table 1 funcref)
    #|  (func $tail (type $tail-type) (param i32))
    #|  (elem (i32.const 0) $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (block (result i32) (i32.const 11))
    #|          (pop i32)
    #|          (i32.const 0)
    #|          (return_call_indirect (type $tail-type)))
    #|        nop)))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected block-result-arg parameterized return_call_indirect pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_indirect"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("block I32"), msg=pretty)
  assert_true(pretty.contains("I32(11)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs binary arg before catch pop parameterized return_call_indirect text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (table 1 funcref)
    #|  (func $tail (type $tail-type) (param i32))
    #|  (elem (i32.const 0) $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (i32.add (i32.const 1) (i32.const 2))
    #|          (pop i32)
    #|          (i32.const 0)
    #|          (return_call_indirect (type $tail-type)))
    #|        nop)))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected binary-arg parameterized return_call_indirect pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_indirect"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("i32.add"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs non-i32 binary arg before catch pop parameterized return_call_indirect text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (table 1 funcref)
    #|  (func $tail (type $tail-type) (param i32))
    #|  (elem (i32.const 0) $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (i64.add (i64.const 1) (i64.const 2))
    #|          (pop i32)
    #|          (i32.const 0)
    #|          (return_call_indirect (type $tail-type)))
    #|        nop)))
    #|  (func $helper (param i64 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected non-i32-binary parameterized return_call_indirect pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_indirect"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("i64.add"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs unary arg before catch pop parameterized return_call_indirect text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (table 1 funcref)
    #|  (func $tail (type $tail-type) (param i32))
    #|  (elem (i32.const 0) $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (i32.eqz (i32.const 0))
    #|          (pop i32)
    #|          (i32.const 0)
    #|          (return_call_indirect (type $tail-type)))
    #|        nop)))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected unary-arg parameterized return_call_indirect pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_indirect"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("i32.eqz"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs loop-result arg before catch pop parameterized return_call_indirect text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (table 1 funcref)
    #|  (func $tail (type $tail-type) (param i32))
    #|  (elem (i32.const 0) $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (loop (result i32) (i32.const 12))
    #|          (pop i32)
    #|          (i32.const 0)
    #|          (return_call_indirect (type $tail-type)))
    #|        nop)))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected loop-result-arg parameterized return_call_indirect pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_indirect"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("loop I32"), msg=pretty)
  assert_true(pretty.contains("I32(12)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs evaluated arg before catch pop parameterized return_call_indirect text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (memory 1)
    #|  (tag $e-i32 (param i32))
    #|  (table 1 funcref)
    #|  (func $tail (type $tail-type) (param i32))
    #|  (elem (i32.const 0) $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (i32.load (i32.const 0))
    #|          (pop i32)
    #|          (i32.const 0)
    #|          (return_call_indirect (type $tail-type)))
    #|        nop)))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected evaluated-arg parameterized return_call_indirect pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_indirect"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs direct call arg before catch pop parameterized return_call_indirect text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (table 1 funcref)
    #|  (func $tail (type $tail-type) (param i32))
    #|  (elem (i32.const 0) $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (call $producer)
    #|          (pop i32)
    #|          (i32.const 0)
    #|          (return_call_indirect (type $tail-type)))
    #|        nop)))
    #|  (func $producer (result i32) (i32.const 13))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call-arg parameterized return_call_indirect pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_indirect"), msg=pretty)
  assert_true(pretty.contains("call (Func 2)"), msg=pretty)
  assert_false(pretty.contains("call (Func 3)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs const arg before catch pop parameterized return_call_ref text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (func $tail (type $tail-type) (param i32))
    #|  (elem declare func $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (i32.const 7)
    #|          (pop i32)
    #|          (ref.func $tail)
    #|          (return_call_ref (type $tail-type)))
    #|        nop)))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected const-arg parameterized return_call_ref pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_ref"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs const arg before catch multi-pop parameterized return_call_ref text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (elem declare func $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (call $helper
    #|          (i32.const 7)
    #|          (pop i32)
    #|          (pop i64)
    #|          (ref.func $tail)
    #|          (return_call_ref (type $tail-type)))
    #|        nop)))
    #|  (func $helper (param i32 i32 i64 funcref)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected const-arg multi-pop parameterized return_call_ref pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_ref"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(3)"), msg=pretty)
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs block-result arg before catch pop parameterized return_call_ref text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (func $tail (type $tail-type) (param i32))
    #|  (elem declare func $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (block (result i32) (i32.const 11))
    #|          (pop i32)
    #|          (ref.func $tail)
    #|          (return_call_ref (type $tail-type)))
    #|        nop)))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected block-result-arg parameterized return_call_ref pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_ref"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("block I32"), msg=pretty)
  assert_true(pretty.contains("I32(11)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs binary arg before catch pop parameterized return_call_ref text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (func $tail (type $tail-type) (param i32))
    #|  (elem declare func $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (i32.add (i32.const 1) (i32.const 2))
    #|          (pop i32)
    #|          (ref.func $tail)
    #|          (return_call_ref (type $tail-type)))
    #|        nop)))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected binary-arg parameterized return_call_ref pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_ref"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("i32.add"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs float binary arg before catch pop parameterized return_call_ref text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (func $tail (type $tail-type) (param i32))
    #|  (elem declare func $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (f64.max (f64.const 1.0) (f64.const 2.0))
    #|          (pop i32)
    #|          (ref.func $tail)
    #|          (return_call_ref (type $tail-type)))
    #|        nop)))
    #|  (func $helper (param f64 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected float-binary parameterized return_call_ref pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_ref"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("f64.max"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs unary arg before catch pop parameterized return_call_ref text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (func $tail (type $tail-type) (param i32))
    #|  (elem declare func $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (i32.eqz (i32.const 0))
    #|          (pop i32)
    #|          (ref.func $tail)
    #|          (return_call_ref (type $tail-type)))
    #|        nop)))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected unary-arg parameterized return_call_ref pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_ref"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("i32.eqz"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs loop-result arg before catch pop parameterized return_call_ref text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (func $tail (type $tail-type) (param i32))
    #|  (elem declare func $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (loop (result i32) (i32.const 12))
    #|          (pop i32)
    #|          (ref.func $tail)
    #|          (return_call_ref (type $tail-type)))
    #|        nop)))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected loop-result-arg parameterized return_call_ref pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_ref"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("loop I32"), msg=pretty)
  assert_true(pretty.contains("I32(12)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs evaluated arg before catch pop parameterized return_call_ref text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (memory 1)
    #|  (tag $e-i32 (param i32))
    #|  (func $tail (type $tail-type) (param i32))
    #|  (elem declare func $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (i32.load (i32.const 0))
    #|          (pop i32)
    #|          (ref.func $tail)
    #|          (return_call_ref (type $tail-type)))
    #|        nop)))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected evaluated-arg parameterized return_call_ref pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_ref"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs binary arg before catch multi-pop parameterized return_call_ref text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func $tail (type $tail-type) (unreachable))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (call $helper
    #|          (i32.const 9)
    #|          (i32.const 2)
    #|          (i32.sub)
    #|          (pop i32)
    #|          (pop i64)
    #|          (ref.func $tail)
    #|          (return_call_ref (type $tail-type)))
    #|        nop)))
    #|  (func $helper (param i32 i32 i64 funcref)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("call (Func 2)"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected binary-arg multi-pop parameterized return_call_ref pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_ref"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(3)"), msg=pretty)
  assert_true(pretty.contains("i32.sub"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs direct call arg before catch pop parameterized return_call_ref text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (func $tail (type $tail-type) (param i32))
    #|  (elem declare func $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (call $producer)
    #|          (pop i32)
    #|          (ref.func $tail)
    #|          (return_call_ref (type $tail-type)))
    #|        nop)))
    #|  (func $producer (result i32) (i32.const 13))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected direct-call-arg parameterized return_call_ref pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_ref"), msg=pretty)
  assert_true(pretty.contains("call (Func 2)"), msg=pretty)
  assert_false(pretty.contains("call (Func 3)"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination preserves catch pop as parameterized return_call operand text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (func $tail (type $tail-type) (param i32))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (pop i32)
    #|        (return_call $tail)
    #|        nop)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected parameterized return_call pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
  assert_false(pretty.contains("local.set"), msg=pretty)
}

///|
test "dead-code-elimination preserves catch pop as parameterized return_call_indirect operand text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (table 1 funcref)
    #|  (func $tail (type $tail-type) (param i32))
    #|  (elem (i32.const 0) $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (pop i32)
    #|        (i32.const 0)
    #|        (return_call_indirect (type $tail-type))
    #|        nop)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected parameterized return_call_indirect pop DCE success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_indirect"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
  assert_false(pretty.contains("local.set"), msg=pretty)
}

///|
test "dead-code-elimination preserves catch pop as parameterized return_call_ref operand text" {
  let source =
    #|(module
    #|  (type $tail-type (func (param i32)))
    #|  (tag $e-i32 (param i32))
    #|  (func $tail (type $tail-type) (param i32))
    #|  (elem declare func $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (pop i32)
    #|        (ref.func $tail)
    #|        (return_call_ref (type $tail-type))
    #|        nop)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected parameterized return_call_ref pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_ref"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
  assert_false(pretty.contains("local.set"), msg=pretty)
}

///|
test "dead-code-elimination repairs catch pop before return_call_indirect text" {
  let source =
    #|(module
    #|  (type $tail-type (func))
    #|  (tag $e-i32 (param i32))
    #|  (table 1 funcref)
    #|  (func $tail (type $tail-type))
    #|  (elem (i32.const 0) $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (pop i32)
    #|        (i32.const 0)
    #|        (return_call_indirect (type $tail-type))
    #|        nop)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected return_call_indirect pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_indirect"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs catch pop before return_call_ref text" {
  let source =
    #|(module
    #|  (type $tail-type (func))
    #|  (tag $e-i32 (param i32))
    #|  (func $tail (type $tail-type))
    #|  (elem declare func $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (pop i32)
    #|        (ref.func $tail)
    #|        (return_call_ref (type $tail-type))
    #|        nop)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected return_call_ref pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_ref"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs dead call arg before catch pop return_call_indirect text" {
  let source =
    #|(module
    #|  (type $tail-type (func))
    #|  (tag $e-i32 (param i32))
    #|  (table 1 funcref)
    #|  (func $tail (type $tail-type))
    #|  (elem (i32.const 0) $tail)
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (pop i32)
    #|          (i32.const 0)
    #|          (return_call_indirect (type $tail-type)))
    #|        nop)))
    #|  (func $helper (param i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected dead-call return_call_indirect pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_indirect"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs evaluated arg before catch pop return_call_ref text" {
  let source =
    #|(module
    #|  (type $tail-type (func))
    #|  (memory 1)
    #|  (tag $e-i32 (param i32))
    #|  (func $tail (type $tail-type))
    #|  (func
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (i32.const 9)
    #|          (i32.load (i32.const 0))
    #|          (pop i32)
    #|          (ref.func $tail)
    #|          (return_call_ref (type $tail-type)))
    #|        nop)))
    #|  (func $helper (param i32 i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(1U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected evaluated-arg return_call_ref pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(1U))
  assert_true(pretty.contains("return_call_ref"), msg=pretty)
  assert_false(pretty.contains("FuncIdx(2)"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs multiple evaluated args before catch pop branch text" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (tag $e-i32 (param i32))
    #|  (func
    #|    (block $label
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32
    #|          (call $helper
    #|            (i32.const 9)
    #|            (i32.load (i32.const 0))
    #|            (pop i32)
    #|            (br $label))
    #|          nop))))
    #|  (func $helper (param i32 i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected multi-arg call-pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("I32(9)"), msg=pretty)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs compound effectful call arg before catch pop branch text" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (tag $e-i32 (param i32))
    #|  (func
    #|    (block $label
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32
    #|          (call $helper
    #|            (i32.add (i32.load (i32.const 0)) (i32.const 1))
    #|            (pop i32)
    #|            (br $label))
    #|          nop))))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected compound effectful call-pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("i32.add"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination preserves catch pop value branch after effectful dead call arg text" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (tag $e-i32 (param i32))
    #|  (func (result i32)
    #|    (block $label (result i32)
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32
    #|          (call $helper
    #|            (i32.load (i32.const 0))
    #|            (pop i32)
    #|            (br $label))
    #|          nop))
    #|      (i32.const 0)))
    #|  (func $helper (param i32 i32 i32)))
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
      fail("expected effectful value-branch call-pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination preserves catch pop value branch after nested dead call arg text" {
  let source =
    #|(module
    #|  (tag $e-i32 (param i32))
    #|  (func (result i32)
    #|    (block $label (result i32)
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32
    #|          (call $helper
    #|            (block (result i32) (i32.const 7))
    #|            (block (result i32) (pop i32))
    #|            (br $label))
    #|          nop))
    #|      (i32.const 0)))
    #|  (func $helper (param i32 i32 i32)))
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
      fail("expected nested value-branch call-pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
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
test "dead-code-elimination preserves catch pop return after effectful dead call arg text" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (tag $e-i32 (param i32))
    #|  (func (result i32)
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (i32.load (i32.const 0))
    #|          (pop i32)
    #|          (return))
    #|        nop))
    #|    (i32.const 0))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected effectful return call-pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("i32.load"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("return"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination preserves catch pop return after nested dead call arg text" {
  let source =
    #|(module
    #|  (tag $e-i32 (param i32))
    #|  (func (result i32)
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (block (result i32) (i32.const 7))
    #|          (block (result i32) (pop i32))
    #|          (return))
    #|        nop))
    #|    (i32.const 0))
    #|  (func $helper (param i32 i32 i32)))
    #|)
    #|
  let before = pass_test_module_from_wat(source).pretty_print_func(
    @lib.FuncIdx::new(0U),
  )
  assert_true(before.contains("pop"), msg=before)
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected nested return call-pop DCE success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("return"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs multi-pop catch dead call before branch text" {
  let source =
    #|(module
    #|  (tag $e-i32-i32 (param i32 i32))
    #|  (func
    #|    (block $label
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32-i32
    #|          (call $helper
    #|            (pop i32)
    #|            (pop i32)
    #|            (br $label))
    #|          nop))))
    #|  (func $helper (param i32 i32 i32)))
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
      fail("expected multi-pop call-pop-catch DCE pipeline success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs catch pop dead call before br_table text" {
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
    #|            (i32.const 0)
    #|            (br_table $label $label))
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
    Err(err) => fail("expected br_table catch-pop DCE pipeline success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("br_table"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs catch pop dead call before local br_table text" {
  let source =
    #|(module
    #|  (tag $e-i32 (param i32))
    #|  (func (param i32)
    #|    (block $label
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32
    #|          (call $helper
    #|            (pop i32)
    #|            (local.get 0)
    #|            (br_table $label $label))
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
    Err(err) =>
      fail("expected local br_table catch-pop DCE pipeline success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("br_table"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs catch pop dead call before computed br_table text" {
  let source =
    #|(module
    #|  (tag $e-i32 (param i32))
    #|  (func (param i32)
    #|    (block $label
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32
    #|          (call $helper
    #|            (pop i32)
    #|            (local.get 0)
    #|            (i32.const 1)
    #|            (i32.and)
    #|            (br_table $label $label))
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
    Err(err) =>
      fail("expected computed br_table catch-pop DCE pipeline success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("br_table"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_true(pretty.contains("i32.and"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs catch pop dead call before arbitrary br_table selector text" {
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
    #|            (i32.const 1)
    #|            (i32.const 1)
    #|            (i32.add)
    #|            (br_table $label $label $label))
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
    Err(err) =>
      fail(
        "expected arbitrary selector br_table catch-pop DCE pipeline success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("br_table"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("i32.add"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs catch pop multivalue br_table computed selector payload" {
  let source =
    #|(module
    #|  (type $pair (func (result i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func (param i32) (result i32 i64)
    #|    (block $label (type $pair)
    #|      (try
    #|        (do nop)
    #|        (catch $e-i64-i32
    #|          (call $helper
    #|            (pop i32)
    #|            (pop i64)
    #|            (local.get 0)
    #|            (i32.const 3)
    #|            (i32.rem_u)
    #|            (br_table $label $label $label))
    #|          nop))
    #|      (i32.const 0)
    #|      (i64.const 0)))
    #|  (func $helper (param i32 i64 i32 i64 i32)))
    #|)
    #|
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected multivalue computed-selector br_table catch-pop DCE pipeline success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("br_table"), msg=pretty)
  assert_true(pretty.contains("i32.rem_u"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination rejects catch pop mismatched arbitrary br_table payload boundary" {
  let source =
    #|(module
    #|  (tag $e-i64 (param i64))
    #|  (func (result i32)
    #|    (block $label (result i32)
    #|      (try
    #|        (do nop)
    #|        (catch $e-i64
    #|          (call $helper
    #|            (pop i64)
    #|            (i32.const 1)
    #|            (i32.const 1)
    #|            (i32.add)
    #|            (br_table $label $label))
    #|          nop))
    #|      (i32.const 0)))
    #|  (func $helper (param i32 i64 i32)))
    #|)
    #|
  match
    @wast.wast_to_binary_module(
      source,
      filename="dce-mismatched-br-table-pop.wat",
    ) {
    Ok(mod_) =>
      fail(
        "mismatched arbitrary br_table catch-pop flow must stay rejected at WAST admission: \{mod_.pretty_print_func(@lib.FuncIdx::new(0U))}",
      )
    Err(err) => assert_true(err.contains("legacy exception pop text"), msg=err)
  }
}

///|
test "dead-code-elimination repairs catch pop carrier after params and locals" {
  let source =
    #|(module
    #|  (tag $e-i32 (param i32))
    #|  (func (param i32 i64) (local i64 i32)
    #|    (block $label
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32
    #|          (call $helper
    #|            (pop i32)
    #|            (local.get 0)
    #|            (br_table $label $label))
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
    Err(err) =>
      fail("expected params/body-locals catch-pop DCE pipeline success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("br_table"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_true(pretty.contains("local.set (Local 4)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 4)"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs catch pop value branch payload" {
  let source =
    #|(module
    #|  (tag $e-i32 (param i32))
    #|  (func (result i32)
    #|    (block $label (result i32)
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32
    #|          (call $helper
    #|            (pop i32)
    #|            (br $label))
    #|          nop))
    #|      (i32.const 0)))
    #|  (func $helper (param i32 i32)))
    #|)
    #|
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected value-branch catch-pop DCE pipeline success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs catch pop value br_table payload" {
  let source =
    #|(module
    #|  (tag $e-i32 (param i32))
    #|  (func (result i32)
    #|    (block $label (result i32)
    #|      (try
    #|        (do nop)
    #|        (catch $e-i32
    #|          (call $helper
    #|            (pop i32)
    #|            (i32.const 0)
    #|            (br_table $label $label))
    #|          nop))
    #|      (i32.const 0)))
    #|  (func $helper (param i32 i32)))
    #|)
    #|
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected value-br_table catch-pop DCE pipeline success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("br_table"), msg=pretty)
  assert_true(pretty.contains("local.set"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_true(pretty.contains("pop"), msg=pretty)
}

///|
test "dead-code-elimination repairs catch pop multivalue branch payload" {
  let source =
    #|(module
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func (result i32 i64)
    #|    (block $label (result i32 i64)
    #|      (try
    #|        (do nop)
    #|        (catch $e-i64-i32
    #|          (call $helper
    #|            (pop i32)
    #|            (pop i64)
    #|            (br $label))
    #|          nop))
    #|      (i32.const 0)
    #|      (i64.const 0)))
    #|  (func $helper (param i32 i64 i32 i64)))
    #|)
    #|
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected multivalue-branch catch-pop DCE pipeline success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs catch pop type-index branch payload" {
  let source =
    #|(module
    #|  (type $pair (func (result i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func (result i32 i64)
    #|    (block $label (type $pair)
    #|      (try
    #|        (do nop)
    #|        (catch $e-i64-i32
    #|          (call $helper
    #|            (pop i32)
    #|            (pop i64)
    #|            (br $label))
    #|          nop))
    #|      (i32.const 0)
    #|      (i64.const 0)))
    #|  (func $helper (param i32 i64 i32 i64)))
    #|)
    #|
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected type-index branch catch-pop DCE pipeline success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("br"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs catch pop type-index br_table payload" {
  let source =
    #|(module
    #|  (type $pair (func (result i32 i64)))
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func (param i32) (result i32 i64)
    #|    (block $label (type $pair)
    #|      (try
    #|        (do nop)
    #|        (catch $e-i64-i32
    #|          (call $helper
    #|            (pop i32)
    #|            (pop i64)
    #|            (local.get 0)
    #|            (br_table $label $label))
    #|          nop))
    #|      (i32.const 0)
    #|      (i64.const 0)))
    #|  (func $helper (param i32 i64 i32 i64 i32)))
    #|)
    #|
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected type-index br_table catch-pop DCE pipeline success: \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("br_table"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_true(pretty.contains("local.get (Local 0)"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs catch pop value return payload" {
  let source =
    #|(module
    #|  (tag $e-i32 (param i32))
    #|  (func (result i32)
    #|    (try
    #|      (do nop)
    #|      (catch $e-i32
    #|        (call $helper
    #|          (pop i32)
    #|          (return))
    #|        nop))
    #|    (i32.const 0))
    #|  (func $helper (param i32 i32)))
    #|)
    #|
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected value-return catch-pop DCE pipeline success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("return"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    1,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    1,
    msg=pretty,
  )
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    1,
    msg=pretty,
  )
}

///|
test "dead-code-elimination repairs catch pop multivalue return payload" {
  let source =
    #|(module
    #|  (tag $e-i64-i32 (param i64 i32))
    #|  (func (result i32 i64)
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64-i32
    #|        (call $helper
    #|          (pop i32)
    #|          (pop i64)
    #|          (return))
    #|        nop))
    #|    (i32.const 0)
    #|    (i64.const 0))
    #|  (func $helper (param i32 i64 i32 i64)))
    #|)
    #|
  let optimized = match
    pass_test_run_pipeline(source, ["dead-code-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected multivalue-return catch-pop DCE pipeline success: \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("call"), msg=pretty)
  assert_true(pretty.contains("return"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.set"),
    2,
    msg=pretty,
  )
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "local.get"),
    2,
    msg=pretty,
  )
  assert_false(pretty.contains("drop"), msg=pretty)
  assert_eq(
    dead_code_elimination_test_count_occurrences(pretty, "pop"),
    2,
    msg=pretty,
  )
}

///|
test "dead-code-elimination rejects catch pop mismatched return payload boundary" {
  let source =
    #|(module
    #|  (tag $e-i64 (param i64))
    #|  (func (result i32)
    #|    (try
    #|      (do nop)
    #|      (catch $e-i64
    #|        (call $helper
    #|          (pop i64)
    #|          (return))
    #|        nop))
    #|    (i32.const 0))
    #|  (func $helper (param i64 i32)))
    #|)
    #|
  match
    @wast.wast_to_binary_module(
      source,
      filename="dce-catch-pop-mismatched-return-boundary.wat",
    ) {
    Ok(mod_) =>
      fail(
        "mismatched nonvoid-return catch-pop flow must stay rejected: \{mod_.pretty_print_func(@lib.FuncIdx::new(0U))}",
      )
    Err(err) => assert_true(err.contains("legacy exception pop text"), msg=err)
  }
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
