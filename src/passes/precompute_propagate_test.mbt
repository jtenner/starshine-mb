///|
test "precompute-propagate preserves multi-read i32 arithmetic locals" {
  let input =
    #|(module
    #|  (global i32 (i32.const 9))
    #|  (func (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    global.get 0
    #|    i32.sub
    #|    local.set 1
    #|    local.get 1
    #|    i32.const 1
    #|    i32.add
    #|    drop
    #|    local.get 1
    #|    return))
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      input,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected i32 arithmetic local success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=multi-read-arithmetic-local-precompute-propagate-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves multi-read arithmetic locals" {
  let input =
    #|(module
    #|  (global i64 (i64.const 9))
    #|  (func (param i64) (result i64) (local i64)
    #|    local.get 0
    #|    global.get 0
    #|    i64.sub
    #|    local.set 1
    #|    local.get 1
    #|    i64.const 1
    #|    i64.add
    #|    drop
    #|    local.get 1
    #|    return))
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      input,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected arithmetic local success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=multi-read-arithmetic-local-precompute-propagate-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves loads before same-local release calls" {
  let input =
    #|(module
    #|  (memory 1)
    #|  (func $alloc (param i32) (result i32) local.get 0)
    #|  (func $init (param i32 i32))
    #|  (func $release-a (param i32))
    #|  (func $predicate (param i32) (result i32) i32.const 0)
    #|  (func $compute (param i32) (result i32) local.get 0)
    #|  (func $release-b (param i32))
    #|  (func (param i32) (result i32)
    #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|    (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|    i32.const 4
    #|    call $alloc
    #|    local.tee 18
    #|    i32.const 0
    #|    call $init
    #|    local.get 18
    #|    i32.const 0
    #|    i32.store
    #|    local.get 18
    #|    local.set 1
    #|    local.get 0
    #|    i32.load
    #|    local.tee 2
    #|    i32.load offset=4
    #|    local.set 3
    #|    local.get 2
    #|    call $release-a
    #|    i32.const 0
    #|    local.set 19
    #|    loop
    #|      block
    #|        block (result i32)
    #|          local.get 19
    #|          local.tee 4
    #|          local.get 3
    #|          i32.lt_s
    #|          if
    #|            local.get 2
    #|            i32.load
    #|            local.tee 7
    #|            local.get 4
    #|            i32.const 2
    #|            i32.shl
    #|            i32.add
    #|            i32.load
    #|            local.set 5
    #|            block (result i32)
    #|              block
    #|                local.get 5
    #|                call $predicate
    #|                local.tee 14
    #|                i32.const 0
    #|                i32.eq
    #|                if
    #|                  local.get 1
    #|                  i32.load
    #|                  local.tee 15
    #|                  i32.const 1
    #|                  i32.add
    #|                  local.set 13
    #|                  local.get 1
    #|                  local.get 13
    #|                  i32.store
    #|                  i32.const 0
    #|                  drop
    #|                else
    #|                  local.get 5
    #|                  local.tee 16
    #|                  i32.load
    #|                  local.tee 8
    #|                  call $release-a
    #|                  local.get 8
    #|                  local.set 6
    #|                  br 1
    #|                end
    #|                i32.const 0
    #|                br 1
    #|              end
    #|              local.get 1
    #|              i32.load
    #|              local.set 10
    #|              local.get 6
    #|              call $compute
    #|              local.set 20
    #|              local.get 6
    #|              call $release-b
    #|              local.get 20
    #|              local.tee 12
    #|              local.set 11
    #|              local.get 10
    #|              local.get 11
    #|              i32.add
    #|              local.set 9
    #|              local.get 1
    #|              local.get 9
    #|              i32.store
    #|              i32.const 0
    #|            end
    #|            drop
    #|            local.get 4
    #|            i32.const 1
    #|            i32.add
    #|            local.tee 17
    #|            br 1
    #|          else
    #|            local.get 2
    #|            call $release-b
    #|          end
    #|          br 1
    #|        end
    #|        local.set 19
    #|        br 1
    #|      end
    #|    end
    #|    i32.const 0
    #|    drop
    #|    local.get 1
    #|    i32.load
    #|    local.get 1
    #|    call $release-b))
  let trace : Array[String] = []
  let output = match
    pass_test_run_pipeline(
      input,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(output) => output
    Err(err) => fail("expected load-before-release success, got \{err}")
  }
  match output.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      let @lib.Func(_, @lib.Expr(body)) = funcs[6]
      let end_ = body.length()
      @debug.assert_eq(
        (body[end_ - 4], body[end_ - 3], body[end_ - 2], body[end_ - 1]),
        (
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::i32_load(@lib.MemArg::new(2U, None, 0UL)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::call(@lib.FuncIdx::new(5U)),
        ),
      )
    }
    None => fail("expected code section")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=load-before-release-precompute-propagate-noop")
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves indexed loads before alias releases" {
  let input =
    #|(module
    #|  (memory 1)
    #|  (func $retain (param i32))
    #|  (func $release (param i32))
    #|  (func (param i32 i32) (result i32) (local i32)
    #|    local.get 0
    #|    call $retain
    #|    local.get 0
    #|    local.tee 2
    #|    local.get 1
    #|    i32.const 2
    #|    i32.shl
    #|    i32.add
    #|    i32.load
    #|    local.get 2
    #|    call $release))
  let original = pass_test_module_from_wat(input)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(
        optimize_level=4,
        shrink_level=4,
        trace=Some(fn(line) { trace.push(line) }),
      ),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected indexed load alias lifetime success, got \{err}")
  }
  @debug.assert_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(2U)),
    original.pretty_print_func(@lib.FuncIdx::new(2U)),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=indexed-load-alias-release-precompute-propagate-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves call results before local reloads" {
  let input =
    #|(module
    #|  (func $fail (param i32) (result i32) local.get 0)
    #|  (func $decode10 (param i32) (result i32) local.get 0)
    #|  (func $wrap (param i32 i32) (result i32) local.get 0)
    #|  (func $finish10 (param i32 i32 i32 i32) (result i32) local.get 0)
    #|  (func $decode16 (param i32) (result i32) local.get 0)
    #|  (func $finish16 (param i32 i32 i32 i32) (result i32) local.get 0)
    #|  (func $decode-other (param i32 i32) (result i32) local.get 0)
    #|  (func $finish-other (param i32 i32 i32 i32 i32) (result i32)
    #|    local.get 0)
    #|  (func (param i32 i32) (result i32)
    #|    (local i32 i32 i32 i32 i32 i32 i32)
    #|    local.get 1
    #|    i32.const 2
    #|    i32.lt_s
    #|    if (result i32)
    #|      i32.const 1
    #|    else
    #|      local.get 1
    #|      i32.const 36
    #|      i32.gt_s
    #|    end
    #|    if
    #|      i32.const 314840
    #|      call $fail
    #|      drop
    #|    end
    #|    i32.const 0
    #|    drop
    #|    local.get 0
    #|    i32.const 0
    #|    i32.eq
    #|    if
    #|      i32.const 207328
    #|      return
    #|    end
    #|    i32.const 0
    #|    drop
    #|    local.get 1
    #|    i32.const 10
    #|    i32.eq
    #|    if (result i32)
    #|      local.get 0
    #|      call $decode10
    #|      local.set 3
    #|      local.get 3
    #|      i32.const 0
    #|      call $wrap
    #|      local.set 4
    #|      local.get 4
    #|      local.get 0
    #|      i32.const 0
    #|      local.get 3
    #|      call $finish10
    #|      drop
    #|      local.get 4
    #|    else
    #|      local.get 1
    #|      i32.const 16
    #|      i32.eq
    #|      if (result i32)
    #|        local.get 0
    #|        call $decode16
    #|        local.set 5
    #|        local.get 5
    #|        i32.const 0
    #|        call $wrap
    #|        local.set 6
    #|        local.get 6
    #|        local.get 0
    #|        i32.const 0
    #|        local.get 5
    #|        call $finish16
    #|        drop
    #|        local.get 6
    #|      else
    #|        local.get 0
    #|        local.get 1
    #|        call $decode-other
    #|        local.set 7
    #|        local.get 7
    #|        i32.const 0
    #|        call $wrap
    #|        local.set 8
    #|        local.get 8
    #|        local.get 0
    #|        i32.const 0
    #|        local.get 7
    #|        local.get 1
    #|        call $finish-other
    #|        drop
    #|        local.get 8
    #|      end
    #|    end
    #|    local.set 2
    #|    local.get 2))
  let original = pass_test_module_from_wat(input)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(
        optimize_level=4,
        shrink_level=4,
        trace=Some(fn(line) { trace.push(line) }),
      ),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected call-result reload success, got \{err}")
  }
  @debug.assert_eq(optimized, original)
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=call-result-local-reload-precompute-propagate-noop")
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves call results carried across release calls" {
  let input =
    #|(module
    #|  (import "env" "produce" (func $produce (param i32 i32 i32) (result i32)))
    #|  (import "env" "release" (func $release (param i32)))
    #|  (import "env" "consume" (func $consume (param i32 i32 i32)))
    #|  (func (param i32 i32 i32) (local i32 i32)
    #|    i32.const 46768
    #|    local.set 3
    #|    local.get 0
    #|    local.get 1
    #|    local.get 3
    #|    call $produce
    #|    local.get 3
    #|    call $release
    #|    local.set 4
    #|    local.get 0
    #|    local.get 4
    #|    local.get 2
    #|    call $consume
    #|    local.get 4
    #|    call $release))
  let original = pass_test_module_from_wat(input)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected release stack carrier success, got \{err}")
  }
  @debug.assert_eq(optimized, original)
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=call-result-release-stack-carrier-precompute-propagate-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves call results across memory stores" {
  let input =
    #|(module
    #|  (memory 1)
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    call 1
    #|    local.set 1
    #|    local.get 0
    #|    local.set 2
    #|    i32.const 0
    #|    local.get 2
    #|    i32.store
    #|    local.get 1
    #|    i32.const 4
    #|    i32.shr_u
    #|    return)
    #|  (func (result i32) i32.const 160))
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      input,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected call/store carrier success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=call-result-memory-store-precompute-propagate-noop")
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves call-local-tee ownership lifetimes" {
  let source =
    #|(module
    #|  (func $make (result i32) i32.const 1)
    #|  (func $consume (param i32) (result i32) local.get 0)
    #|  (func $release (param i32)
    #|    local.get 0
    #|    i32.eqz
    #|    if unreachable end)
    #|  (func (export "run") (result i32) (local i32 i32 i32)
    #|    call $make
    #|    local.tee 0
    #|    call $consume
    #|    local.get 0
    #|    call $release
    #|    local.tee 1
    #|    call $consume
    #|    local.get 1
    #|    call $release
    #|    local.set 2
    #|    local.get 2))
  let original = pass_test_module_from_wat(source)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ownership lifetime preservation, got \{err}")
  }
  @debug.assert_eq(optimized, original)
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=call-local-tee-lifetime-precompute-propagate-noop")
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves structured call-result lifetimes" {
  let source =
    #|(module
    #|  (func $make (result i32) i32.const 1)
    #|  (func $convert (param i32) (result i32) local.get 0)
    #|  (func $release (param i32))
    #|  (func (result i32) (local i32 i32)
    #|    call $make
    #|    local.set 0
    #|    local.get 0
    #|    call $convert
    #|    local.get 0
    #|    if
    #|      local.get 0
    #|      call $release
    #|    end
    #|    local.set 1
    #|    local.get 1))
  let original = pass_test_module_from_wat(source)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected structured lifetime preservation, got \{err}")
  }
  @debug.assert_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(3U)),
    original.pretty_print_func(@lib.FuncIdx::new(3U)),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=call-result-structured-lifetime-precompute-propagate-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves effect-bracketed multivalue spills" {
  let source =
    #|(module
    #|  (func $side)
    #|  (func $make (result i32 i32 i32)
    #|    i32.const 1
    #|    i32.const 2
    #|    i32.const 3)
    #|  (func $consume (param i32 i32 i32) (result i32)
    #|    local.get 0)
    #|  (func $release (param i32))
    #|  (func (result i32) (local i32 i32 i32)
    #|    call $side
    #|    call $make
    #|    local.set 2
    #|    local.set 1
    #|    local.tee 0
    #|    local.get 1
    #|    local.get 2
    #|    call $consume
    #|    drop
    #|    local.get 0
    #|    call $release
    #|    local.get 1))
  let original = pass_test_module_from_wat(source)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected multivalue spill preservation, got \{err}")
  }
  @debug.assert_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(4U)),
    original.pretty_print_func(@lib.FuncIdx::new(4U)),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=effect-bracketed-multivalue-call-precompute-propagate-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves call arguments until structured release" {
  let source =
    #|(module
    #|  (func $use (param i32 i32 i32))
    #|  (func $release (param i32))
    #|  (func (param i32) (local i32 i32 i32)
    #|    local.get 0
    #|    local.tee 2
    #|    local.set 3
    #|    i32.const 0
    #|    local.set 1
    #|    i32.const 70608
    #|    local.get 1
    #|    local.get 3
    #|    call $use
    #|    local.get 1
    #|    if
    #|      local.get 1
    #|      call $release
    #|    end
    #|    local.get 3
    #|    if
    #|      local.get 3
    #|      call $release
    #|    end))
  let original = pass_test_module_from_wat(source)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected call argument lifetime preservation, got \{err}")
  }
  @debug.assert_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(2U)),
    original.pretty_print_func(@lib.FuncIdx::new(2U)),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=call-argument-structured-release-precompute-propagate-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves call arguments until direct release" {
  let source =
    #|(module
    #|  (func $use (param i32 i32 i32))
    #|  (func $release (param i32))
    #|  (func (param i32 i32)
    #|    i32.const 70032
    #|    local.get 0
    #|    local.get 1
    #|    call $use
    #|    local.get 0
    #|    call $release
    #|    local.get 1
    #|    call $release))
  let original = pass_test_module_from_wat(source)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected direct release lifetime preservation, got \{err}")
  }
  @debug.assert_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(2U)),
    original.pretty_print_func(@lib.FuncIdx::new(2U)),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=call-argument-direct-release-precompute-propagate-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves a single constant argument until its later call" {
  let source =
    #|(module
    #|  (func $use (param i32 i32 i32) (result i32) local.get 0)
    #|  (func $release (param i32))
    #|  (func (param i32 i32) (result i32) (local i32)
    #|    i32.const 46752
    #|    local.set 2
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    call $use
    #|    local.get 2
    #|    call $release))
  let original = pass_test_module_from_wat(source)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected single call lifetime preservation, got \{err}")
  }
  @debug.assert_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(2U)),
    original.pretty_print_func(@lib.FuncIdx::new(2U)),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=single-argument-distinct-call-lifetime-precompute-propagate-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves wide call arguments until matching releases" {
  let source =
    #|(module
    #|  (func $use (param i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|             (param i32 i32 i32 i32 i32 i32 i32 i32 i32))
    #|  (func $release (param i32))
    #|  (func (param i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|        (param i32 i32 i32 i32 i32 i32 i32 i32 i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    local.get 3
    #|    local.get 4
    #|    local.get 5
    #|    local.get 6
    #|    local.get 7
    #|    local.get 8
    #|    local.get 9
    #|    local.get 10
    #|    local.get 11
    #|    local.get 12
    #|    local.get 13
    #|    local.get 14
    #|    local.get 15
    #|    local.get 16
    #|    local.get 17
    #|    call $use
    #|    local.get 0
    #|    if
    #|      local.get 0
    #|      call $release
    #|    end
    #|    local.get 1
    #|    call $release
    #|    local.get 2
    #|    call $release
    #|    local.get 3
    #|    call $release
    #|    local.get 4
    #|    call $release
    #|    local.get 5
    #|    call $release
    #|    local.get 6
    #|    call $release
    #|    local.get 7
    #|    call $release
    #|    local.get 8
    #|    call $release
    #|    local.get 9
    #|    call $release
    #|    local.get 10
    #|    call $release
    #|    local.get 11
    #|    call $release
    #|    local.get 12
    #|    call $release
    #|    local.get 13
    #|    call $release
    #|    local.get 14
    #|    call $release
    #|    local.get 15
    #|    call $release
    #|    local.get 16
    #|    call $release
    #|    local.get 17
    #|    call $release))
  let original = pass_test_module_from_wat(source)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected wide call lifetime preservation, got \{err}")
  }
  @debug.assert_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(2U)),
    original.pretty_print_func(@lib.FuncIdx::new(2U)),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=call-argument-direct-release-precompute-propagate-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves dropped call results across later effectful calls" {
  let source =
    #|(module
    #|  (func $produce (param i32 i32 i32 i32) (result i32)
    #|    local.get 0)
    #|  (func $release (param i32))
    #|  (func (param i32) (local i32 i32 i32 i32)
    #|    local.get 0
    #|    local.tee 1
    #|    i32.const 0
    #|    i32.const 3
    #|    local.set 4
    #|    local.set 3
    #|    local.set 2
    #|    i32.const 10
    #|    local.get 2
    #|    local.get 3
    #|    local.get 4
    #|    call $produce
    #|    local.get 2
    #|    call $release
    #|    drop))
  let original = pass_test_module_from_wat(source)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected dropped-result call order preservation, got \{err}")
  }
  @debug.assert_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(2U)),
    original.pretty_print_func(@lib.FuncIdx::new(2U)),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=dropped-call-result-effect-order-precompute-propagate-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves comparison values stored for later flag reads" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    local.get 0
    #|    i32.const 0
    #|    i32.lt_s
    #|    local.set 1
    #|    local.get 1
    #|    if (result i32)
    #|      i32.const 0
    #|      local.get 0
    #|      i32.sub
    #|      local.tee 2
    #|    else
    #|      local.get 0
    #|    end
    #|    local.set 2
    #|    local.get 1
    #|    if (result i32)
    #|      i32.const 1
    #|    else
    #|      i32.const 0
    #|    end
    #|    local.get 2
    #|    i32.add))
  let original = pass_test_module_from_wat(source)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(
        optimize_level=4,
        shrink_level=4,
        trace=Some(fn(line) { trace.push(line) }),
      ),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected comparison flag preservation, got \{err}")
  }
  @debug.assert_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(0U)),
    original.pretty_print_func(@lib.FuncIdx::new(0U)),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=comparison-flag-if-precompute-propagate-noop")
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves parameters read before later writes" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    i32.load
    #|    drop
    #|    local.get 0
    #|    i32.const 0
    #|    i32.gt_s
    #|    local.set 1
    #|    i32.const 7
    #|    local.set 0
    #|    local.get 1))
  let original = pass_test_module_from_wat(source)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected parameter lifetime preservation, got \{err}")
  }
  @debug.assert_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(0U)),
    original.pretty_print_func(@lib.FuncIdx::new(0U)),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=parameter-read-before-write-precompute-propagate-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate folds local-carried constants that plain precompute leaves" {
  let source = "(module (func (result i32) (local i32) i32.const 10 local.set 0 local.get 0 local.get 0 i32.add))"
  let plain = match pass_test_run_pipeline(source, ["precompute"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected plain precompute success, got \{err}")
  }
  assert_true(plain.contains("local.get"), msg=plain)

  let propagated = match
    pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected precompute-propagate success, got \{err}")
  }
  assert_true(propagated.contains("I32(20)"), msg=propagated)
  assert_false(propagated.contains("i32.add"), msg=propagated)
}

///|
test "precompute-propagate folds identical reaching-set constants" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    if
    #|      i32.const 10
    #|      local.set 1
    #|    else
    #|      i32.const 10
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    local.get 1
    #|    i32.add))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected identical-merge propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(20)"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
}

///|
test "precompute-propagate preserves differing reaching-set values" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    if
    #|      i32.const 10
    #|      local.set 1
    #|    else
    #|      i32.const 20
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    local.get 1
    #|    i32.add))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected differing-merge propagation success, got \{err}")
  }
  assert_true(pretty.contains("local.get"), msg=pretty)
  assert_true(pretty.contains("i32.add"), msg=pretty)
}

///|
test "precompute-propagate merges defaultable local entry zero with explicit zero" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    if
    #|      i32.const 0
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    local.get 1
    #|    i32.add))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected default-entry propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(0)"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
}

///|
test "precompute-propagate preserves locals written inside dropped result blocks" {
  let source =
    #|(module
    #|  (func (export "run") (result i64) (local i64)
    #|    block (result i64)
    #|      i64.const 100
    #|      local.set 0
    #|      i64.const 7
    #|    end
    #|    local.get 0
    #|    i64.add))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) =>
      fail("expected dropped result-block local preservation, got \{err}")
  }
  assert_true(pretty.contains("I64(107)"), msg=pretty)
}

///|
test "precompute-propagate reasons through tee and block fallthrough values" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    block (result i32)
    #|      nop
    #|      i32.const 7
    #|      local.tee 1
    #|    end
    #|    local.set 0
    #|    local.get 0
    #|    local.get 1
    #|    i32.add))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected fallthrough propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(14)"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
}

///|
test "precompute-propagate preserves branch-written local after nested result if" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32) (local i32 i32)
    #|    local.get 0
    #|    if (result i32)
    #|      local.get 1
    #|      local.set 2
    #|      i32.const 0
    #|    else
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.set 2
    #|      i32.const 1
    #|    end
    #|    local.set 3
    #|    local.get 2))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected nested-result-if boundary success, got \{err}")
  }
  assert_true(pretty.contains("(local.get (Local 2))"), msg=pretty)
  assert_false(pretty.contains("I32(0))(end)"), msg=pretty)
}

///|
test "precompute-propagate preserves prior fact across branch writes in nested result if" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32) (local i32 i32)
    #|    i32.const 42
    #|    local.set 2
    #|    local.get 0
    #|    if (result i32)
    #|      local.get 1
    #|      local.set 2
    #|      i32.const 0
    #|    else
    #|      local.get 1
    #|      i32.const 1
    #|      i32.add
    #|      local.set 2
    #|      i32.const 1
    #|    end
    #|    local.set 3
    #|    local.get 2))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected stale-prior-fact boundary success, got \{err}")
  }
  assert_true(pretty.contains("(local.get (Local 2))"), msg=pretty)
  assert_false(pretty.contains("I32(42))(end)"), msg=pretty)
}

///|
test "precompute-propagate folds constants in high-local large lowered functions" {
  let source = StringBuilder::new()
  source.write_string("(module (func (result i32) (local")
  for _idx = 0; _idx < 65; _idx = _idx + 1 {
    source.write_string(" i32")
  }
  source.write_string(") i32.const 10 local.set 0")
  for _idx = 0; _idx < 501; _idx = _idx + 1 {
    source.write_string(" nop")
  }
  source.write_string(" local.get 0 local.get 0 i32.add))")
  let pretty = match
    pass_test_run_pipeline(source.to_string(), ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected large-function propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(20)"), msg=pretty)
  assert_false(pretty.contains("local.get"), msg=pretty)
  assert_false(pretty.contains("i32.add"), msg=pretty)
}

///|
test "precompute-propagate defers call-result locals beside memory copy" {
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
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected call-result memory-copy boundary, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains("reason=call-result-memory-copy-precompute-propagate-noop")
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves locals written from result-if values" {
  let optimized = match
    pass_test_run_pipeline(
      (
        #|(module
        #|  (func (param i32) (result i32) (local i32)
        #|    local.get 0
        #|    if (result i32)
        #|      i32.const 7
        #|    else
        #|      i32.const 9
        #|    end
        #|    local.tee 1
        #|    drop
        #|    local.get 1))
        #|,
      ),
      ["precompute-propagate"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected result-if local propagation success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("local.tee (Local 1)"), msg=pretty)
  assert_true(pretty.contains("local.get (Local 1)"), msg=pretty)
}

///|
test "precompute-propagate preserves stack-carried overwritten local pairs" {
  let input =
    #|(module
    #|  (func $use (param i32 i32 i32 i32 i32))
    #|  (func (param i32 i32 i32)
    #|    local.get 0
    #|    i32.const 0
    #|    local.get 1
    #|    local.set 0
    #|    local.get 0
    #|    i32.const 0
    #|    local.get 2
    #|    call $use))
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      input,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected overwritten-local pair success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=stack-carried-overwritten-local-precompute-propagate-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves overwritten locals before multi-arg calls" {
  let input =
    #|(module
    #|  (func $use (param i32 i32 i32))
    #|  (func (param i32 i32) (local i32)
    #|    local.get 0
    #|    local.set 2
    #|    local.get 2
    #|    local.get 1
    #|    local.set 2
    #|    local.get 2
    #|    local.get 0
    #|    call $use))
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      input,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(_) => ()
    Err(err) => fail("expected multi-arg overwritten-local success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=stack-carried-overwritten-local-precompute-propagate-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate preserves stack-carried overwritten locals" {
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
  let original = pass_test_module_from_wat(input)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected overwritten-local carrier success, got \{err}")
  }
  @debug.assert_eq(
    optimized.pretty_print_func(@lib.FuncIdx::new(1U)),
    original.pretty_print_func(@lib.FuncIdx::new(1U)),
  )
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=stack-carried-overwritten-local-precompute-propagate-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate accepts terminal branches to the function label" {
  let void_type = @lib.TypeIdx::new(0U)
  let value_type = @lib.TypeIdx::new(1U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([void_type, value_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([@lib.Instruction::br(@lib.LabelIdx::new(0U))]),
        ),
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(7)),
            @lib.Instruction::br(@lib.LabelIdx::new(0U)),
          ]),
        ),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["precompute-propagate"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected function-label branch support, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("expected valid function-label branch output, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      @debug.assert_eq(funcs.length(), 2)
      let @lib.Func(_, @lib.Expr(void_body)) = funcs[0]
      let @lib.Func(_, @lib.Expr(value_body)) = funcs[1]
      match void_body {
        [@lib.Br(@lib.LabelIdx(raw))] => @debug.assert_eq(raw, 0U)
        _ => fail("expected void function-label branch, got \{void_body}")
      }
      match value_body {
        [@lib.I32Const(@lib.I32(7)), @lib.Br(@lib.LabelIdx(raw))] =>
          @debug.assert_eq(raw, 0U)
        _ => fail("expected value function-label branch, got \{value_body}")
      }
    }
    None => fail("expected code section")
  }
}

///|
test "precompute-propagate clears labels for folded empty root blocks" {
  let source =
    #|(module
    #|  (func (result i32) (local i32)
    #|    local.get 0
    #|    i32.eqz
    #|    i32.eqz
    #|    if
    #|      i32.const 7
    #|      return
    #|    end
    #|    i32.const 9))
  let optimized = match
    pass_test_run_pipeline(
      source,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(
        verify_policy=HotPipelineVerifyPolicy::after_each_pass(),
      ),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected folded empty-root label cleanup, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(9)"), msg=pretty)
  assert_false(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("if "), msg=pretty)
}

///|
test "precompute-propagate bounds high-local branch label ownership" {
  let source = StringBuilder::new()
  source.write_string("(module (func (result i32) (local")
  for _idx = 0; _idx < 129; _idx = _idx + 1 {
    source.write_string(" i32")
  }
  source.write_string(")")
  for _idx = 0; _idx < 16; _idx = _idx + 1 {
    source.write_string(" block br 0 end")
  }
  source.write_string(" i32.const 0))")
  let input = source.to_string()
  let original = pass_test_module_from_wat(input)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected high-local branch boundary success, got \{err}")
  }
  @debug.assert_eq(optimized, original)
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=large-branch-local-label-owner-precompute-propagate-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate fails closed on nested empty-block label-owner shells" {
  // The flattened json-as classifier shape reaches an unsupported HOT label-owner
  // mutation path in the propagating pass. Preserve it until that ownership path
  // can be rewritten without invalidating the surrounding control labels.
  let input =
    #|(module
    #|  (func (param i32) (result i32)
    #|    local.get 0
    #|    if
    #|      block
    #|        block
    #|        end
    #|        i32.const 1
    #|        return
    #|      end
    #|    end
    #|    i32.const 0))
  let original = pass_test_module_from_wat(input)
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["precompute-propagate"],
      options=HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected nested empty-block boundary success, got \{err}")
  }
  @debug.assert_eq(optimized, original)
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "reason=nested-empty-block-label-owner-precompute-propagate-noop",
      )
    }),
    msg=trace.to_string(),
  )
}

///|
test "precompute-propagate performs one propagation solve and one evaluator rerun" {
  let source =
    #|(module
    #|  (func (param i32 i32 i32) (result i32) (local i32)
    #|    local.get 3
    #|    if
    #|      i32.const 24
    #|      local.set 3
    #|    end
    #|    local.get 3
    #|    if
    #|      i32.const 0
    #|      local.set 2
    #|    end
    #|    local.get 2))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected bounded propagation success, got \{err}")
  }
  assert_true(pretty.contains("(if"), msg=pretty)
  assert_true(pretty.contains("(local.get (Local 3))"), msg=pretty)
}

///|
test "precompute-propagate merges agreeing writes from result if arms" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32)
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 1
    #|      i32.const 0
    #|    else
    #|      i32.const 7
    #|      local.set 1
    #|      i32.const 1
    #|    end
    #|    drop
    #|    local.get 1))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected result-if merge propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(7)"), msg=pretty)
  assert_false(pretty.contains("(local.get (Local 1))"), msg=pretty)
}

///|
test "precompute-propagate carries tee constants into selected result if arms" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func (param i32) (result i32) (local i32 i32)
    #|    local.get 0
    #|    local.tee 1
    #|    i32.const 5
    #|    local.tee 2
    #|    i32.lt_s
    #|    if (result i32)
    #|      local.get 2
    #|      local.get 1
    #|      i32.sub
    #|    else
    #|      i32.const 0
    #|    end))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected tee fact propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(5)"), msg=pretty)
  assert_false(pretty.contains("(local.get (Local 2))"), msg=pretty)
}

///|
test "precompute-propagate raw-cleans supported values around unsupported atomic fences" {
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
          ]),
        ),
      ]),
    )
  let pretty = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected atomic raw cleanup success, got \{err}")
  }
  assert_true(pretty.contains("atomic.fence"), msg=pretty)
  assert_false(pretty.contains("i32.div_s"), msg=pretty)
  assert_false(pretty.contains("f64.add"), msg=pretty)
  assert_false(pretty.contains("drop"), msg=pretty)
}

///|
test "precompute-propagate preserves legacy catch-all try flow" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::try_(
              @lib.BlockType::val_type(@lib.ValType::i32()),
              @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(1))]),
              [
                @lib.LegacyCatch::all(
                  @lib.Expr::new([@lib.Instruction::i32_const(@lib.I32(2))]),
                ),
              ],
            ),
          ]),
        ),
      ]),
    )
  let pretty = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected legacy try preservation success, got \{err}")
  }
  assert_true(pretty.contains("(try"), msg=pretty)
  assert_true(pretty.contains("I32(1)"), msg=pretty)
  assert_true(pretty.contains("I32(2)"), msg=pretty)
}

///|
test "precompute-propagate keeps condition tee facts despite unrelated result-if arm writes" {
  let source =
    #|(module
    #|  (func (param i32) (result i32) (local i32 i32 i32)
    #|    local.get 0
    #|    i32.const 5
    #|    local.tee 2
    #|    i32.lt_s
    #|    if (result i32)
    #|      local.get 2
    #|    else
    #|      i32.const 0
    #|    end
    #|    local.set 3
    #|    local.get 0
    #|    if (result i32)
    #|      i32.const 7
    #|      local.set 2
    #|      i32.const 0
    #|    else
    #|      i32.const 9
    #|      local.set 2
    #|      i32.const 1
    #|    end
    #|    local.set 1
    #|    local.get 3))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected condition tee propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(5)"), msg=pretty)
  assert_false(pretty.contains("(local.get (Local 2))"), msg=pretty)
}

///|
test "precompute-propagate raw control propagation keeps loop invariants" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $sink (param i32))
    #|  (func (param i32) (local i32 i32)
    #|    i32.const 290192
    #|    local.set 1
    #|    memory.size
    #|    drop
    #|    loop
    #|      local.get 1
    #|      drop
    #|      local.get 0
    #|      br_if 0
    #|    end
    #|    local.get 1
    #|    call $sink))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(1U))
    Err(err) =>
      fail("expected raw loop-invariant propagation success, got \{err}")
  }
  assert_true(pretty.contains("I32(290192)"), msg=pretty)
  assert_false(pretty.contains("(local.get (Local 1))"), msg=pretty)
}

///|
test "precompute-propagate preserves typed loop-carried local tees" {
  let source =
    #|(module
    #|  (func (param $limit i32) (local $i i32)
    #|    i32.const 0
    #|    loop (param i32)
    #|      local.tee $i
    #|      local.get $limit
    #|      i32.lt_s
    #|      if
    #|        local.get $i
    #|        i32.const 1
    #|        i32.add
    #|        br 1
    #|      end
    #|    end))
    #|
  let trace = match pass_test_capture_trace(source, ["precompute-propagate"]) {
    Ok(trace) => trace
    Err(err) => fail("expected typed-loop propagation boundary, got \{err}")
  }
  assert_true(
    trace.any(fn(line) { line.contains("reason=typed-loop-param-control") }),
    msg=trace.to_string(),
  )
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(0U))
    Err(err) => fail("expected typed-loop local preservation, got \{err}")
  }
  assert_true(pretty.contains("local.tee"), msg=pretty)
  assert_true(pretty.contains("local.get"), msg=pretty)
}

///|
test "precompute-propagate raw control propagation does not fold loop-carried locals" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func $sink)
    #|  (func (local i32)
    #|    i32.const 0
    #|    local.set 0
    #|    loop
    #|      local.get 0
    #|      i32.const 1
    #|      i32.add
    #|      local.set 0
    #|      local.get 0
    #|      i32.const 3
    #|      i32.lt_s
    #|      br_if 0
    #|    end
    #|    i32.const 0
    #|    i32.load
    #|    drop
    #|    call $sink))
    #|
  let pretty = match pass_test_run_pipeline(source, ["precompute-propagate"]) {
    Ok(mod_) => mod_.pretty_print_func(@lib.FuncIdx::new(1U))
    Err(err) => fail("expected loop-carried local preservation, got \{err}")
  }
  assert_true(pretty.contains("i32.lt_s"), msg=pretty)
  assert_true(pretty.contains("(local.get (Local 0))"), msg=pretty)
}
