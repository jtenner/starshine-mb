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
test "precompute skips O4z raw pass until self-opt ownership hazards are safe" {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      "(module (func (result i32) i32.const 1 i32.const 2 i32.add))",
      ["precompute"],
      options=HotPipelineOptions::new(
        optimize_level=4,
        shrink_level=1,
        trace=Some(fn(line) { trace.push(line) }),
      ),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected O4z precompute skip success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("pass[precompute]:skip-raw reason=o4z-precompute-noop")
    }),
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
    Err(err) => fail("expected precompute branch debris cleanup success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("br_if"), msg=pretty)
  assert_false(pretty.contains("I32(1)"), msg=pretty)
  assert_false(pretty.contains("I32(0)"), msg=pretty)
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
  assert_true(text.contains("LocalTee"), msg=text)
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
