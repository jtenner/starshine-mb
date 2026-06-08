///|
fn remove_unused_names_test_body(text : String) -> Array[@lib.Instruction] {
  let optimized = match pass_test_run_pipeline(text, ["remove-unused-names"]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected remove-unused-names success, got \{err}")
  }
  match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) => body
    _ => abort("expected optimized single-function body")
  }
}

///|
fn remove_unused_names_o4z_run(
  text : String,
  passes? : Array[String] = ["remove-unused-names"],
) -> (Array[@lib.Instruction], Array[String]) {
  let trace : Array[String] = []
  let optimized = match
    pass_test_run_pipeline(
      text,
      passes,
      options=HotPipelineOptions::new(
        optimize_level=4,
        shrink_level=1,
        trace=Some(fn(line) { trace.push(line) }),
      ),
    ) {
    Ok(mod_) => mod_
    Err(err) => abort("expected O4z remove-unused-names success, got \{err}")
  }
  let body = match optimized.code_sec {
    Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) => body
    _ => abort("expected optimized single-function body")
  }
  (body, trace)
}

///|
fn remove_unused_names_trace_contains(
  trace : Array[String],
  needle : String,
) -> Bool {
  trace.any(fn(line) { line.contains(needle) })
}

///|
fn remove_unused_names_o4z_accounted(trace : Array[String]) -> Bool {
  !remove_unused_names_trace_contains(
    trace, "pass[remove-unused-names]:skip-raw reason=o4z-remove-unused-names-noop",
  )
}

///|
test "remove-unused-names O4z accounts for branchless same-typed block peel" {
  // RUN shape inventory: no-label-use same-type block peel; this should run
  // through the raw O4z lane instead of the historical blanket no-op guard.
  let (body, trace) = remove_unused_names_o4z_run(
    "(module (func block block nop end end))",
  )
  assert_true(
    remove_unused_names_o4z_accounted(trace),
    msg="RUN O4z shape still hidden behind blanket no-op guard: branchless same-typed block peel; trace=\{trace}",
  )
  match body {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr([]))] => ()
    other => fail("expected O4z raw block peel, got \{other}")
  }
}

///|
test "remove-unused-names O4z accounts for branchless typed value block peel" {
  // RUN shape inventory: same-type single-child blocks with an explicit result
  // type. Type equality is the safety condition; O4z must not skip this case.
  let (body, trace) = remove_unused_names_o4z_run(
    "(module (type (func (result i32))) (func (result i32) block (type 0) block (type 0) i32.const 7 end end))",
  )
  assert_true(
    remove_unused_names_o4z_accounted(trace),
    msg="RUN O4z shape still hidden behind blanket no-op guard: branchless typed value block peel; trace=\{trace}",
  )
  match body {
    [
      @lib.Block(
        @lib.TypeIdxBlockType(@lib.TypeIdx(0)),
        @lib.Expr([@lib.I32Const(@lib.I32(7))])
      ),
    ] => ()
    other => fail("expected O4z typed block peel, got \{other}")
  }
}

///|
test "remove-unused-names O4z accounts for recursive branchless if bodies" {
  // RUN edge case: branchless recursive control bodies should use the raw
  // rewrite, not require HOT fallback merely because the candidate is nested.
  let (body, trace) = remove_unused_names_o4z_run(
    "(module (func i32.const 0 if block block nop end end else block block nop end end end))",
  )
  assert_true(
    remove_unused_names_o4z_accounted(trace),
    msg="RUN O4z shape still hidden behind blanket no-op guard: branchless nested if body peel; trace=\{trace}",
  )
  match body {
    [
      @lib.I32Const(@lib.I32(0)),
      @lib.If(
        _,
        [@lib.Block(_, @lib.Expr([]))],
        Some([@lib.Block(_, @lib.Expr([]))])
      ),
    ] => ()
    other => fail("expected O4z nested if body block peels, got \{other}")
  }
}

///|
test "remove-unused-names O4z accounts for dead-label loop demotion" {
  // RUN shape inventory: loops with no syntactic continue target are dead
  // control labels and should demote even under O4z.
  let (body, trace) = remove_unused_names_o4z_run(
    "(module (func loop nop end))",
  )
  assert_true(
    remove_unused_names_o4z_accounted(trace),
    msg="RUN O4z shape still hidden behind blanket no-op guard: dead-label loop demotion; trace=\{trace}",
  )
  match body {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr([]))] => ()
    other =>
      fail("expected O4z loop demotion into an empty block, got \{other}")
  }
}

///|
test "remove-unused-names O4z accounts for stale label-name cleanup" {
  // RUN metadata edge case: structural control rewrites make label-name maps
  // stale. O4z must account for the same metadata cleanup as the direct pass.
  let name_sec = @lib.NameSec::new(
    func_names=Some(
      @lib.NameMap::new([
        @lib.NameAssoc::new(0U, @lib.Name::from_string("kept-func")),
      ]),
    ),
    label_names=Some(
      @lib.IndirectNameMap::new([
        @lib.IndirectNameAssoc::new(
          0U,
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("stale-label")),
          ]),
        ),
      ]),
    ),
  )
  let trace : Array[String] = []
  let input = pass_test_module_from_wat(
    "(module (func block block nop end end))",
  ).with_name_sec(name_sec)
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(
        optimize_level=4,
        shrink_level=1,
        trace=Some(fn(line) { trace.push(line) }),
      ),
      ["remove-unused-names"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected O4z label-name cleanup success, got \{err}")
  }
  assert_true(
    remove_unused_names_o4z_accounted(trace),
    msg="RUN O4z shape still hidden behind blanket no-op guard: stale label-name cleanup; trace=\{trace}",
  )
  @debug.assert_eq(
    optimized.name_sec,
    Some(
      @lib.NameSec::new(
        func_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("kept-func")),
          ]),
        ),
      ),
    ),
  )
}

///|
test "remove-unused-names O4z accounts for parent-target branch retargeting" {
  // RUN shape inventory: same-type parent/child merge with a branch that
  // targets the parent. This is not branchless raw cleanup; it must be either
  // safely HOT-enabled in O4z or covered by a narrow explicit guard until then.
  let (body, trace) = remove_unused_names_o4z_run(
    "(module (func block block br 1 end end))",
  )
  assert_true(
    remove_unused_names_o4z_accounted(trace),
    msg="RUN O4z shape still hidden behind blanket no-op guard: parent-target br retargeting; trace=\{trace}",
  )
  match body {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr([@lib.Br(@lib.LabelIdx(0))]))] =>
      ()
    other => fail("expected O4z parent-target br retarget, got \{other}")
  }
}

///|
test "remove-unused-names O4z accounts for parent-target br_if retargeting" {
  // RUN edge case: BranchUtils-style target replacement must cover conditional
  // branches, not just plain br.
  let (body, trace) = remove_unused_names_o4z_run(
    "(module (func block block i32.const 1 br_if 1 end end))",
  )
  assert_true(
    remove_unused_names_o4z_accounted(trace),
    msg="RUN O4z shape still hidden behind blanket no-op guard: parent-target br_if retargeting; trace=\{trace}",
  )
  match body {
    [
      @lib.Block(
        @lib.VoidBlockType,
        @lib.Expr([@lib.I32Const(@lib.I32(1)), @lib.BrIf(@lib.LabelIdx(0))])
      ),
    ] => ()
    other => fail("expected O4z parent-target br_if retarget, got \{other}")
  }
}

///|
test "remove-unused-names O4z accounts for parent-target br_table retargeting" {
  // RUN edge case: same-type parent/child retargeting must include every
  // br_table arm and fallback target.
  let (body, trace) = remove_unused_names_o4z_run(
    "(module (func block block i32.const 0 br_table 1 0 end end))",
  )
  assert_true(
    remove_unused_names_o4z_accounted(trace),
    msg="RUN O4z shape still hidden behind blanket no-op guard: parent-target br_table retargeting; trace=\{trace}",
  )
  match body {
    [
      @lib.Block(
        @lib.VoidBlockType,
        @lib.Expr(
          [
            @lib.I32Const(@lib.I32(0)),
            @lib.BrTable([@lib.LabelIdx(0)], @lib.LabelIdx(0)),
          ]
        )
      ),
    ] => ()
    other => fail("expected O4z parent-target br_table retarget, got \{other}")
  }
}

///|
test "remove-unused-names O4z accounts for repeated RUN slots after branch cleanup" {
  // RUN scheduler shape: remove-unused-brs can make a following RUN slot newly
  // profitable. The repeated O4z slot must be accounted for, not swallowed by a
  // blanket no-op.
  let (body, trace) = remove_unused_names_o4z_run(
    "(module (func block block br 0 end end))",
    passes=["remove-unused-names", "remove-unused-brs", "remove-unused-names"],
  )
  assert_true(
    remove_unused_names_o4z_accounted(trace),
    msg="RUN O4z shape still hidden behind blanket no-op guard: repeated RUN after remove-unused-brs; trace=\{trace}",
  )
  match body {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr([@lib.Br(@lib.LabelIdx(0))]))] =>
      ()
    other =>
      fail(
        "expected repeated O4z RUN to account for remaining branch cleanup, got \{other}",
      )
  }
}

///|
test "remove-unused-names O4z accounts for still-targeted block labels" {
  // RUN edge case: syntactic label uses inside a peelable same-type block chain
  // must be retargeted to the surviving wrapper when the old target becomes
  // equivalent after the peel.
  let (body, trace) = remove_unused_names_o4z_run(
    "(module (func block block i32.const 0 if br 1 else nop end end end))",
  )
  assert_true(
    remove_unused_names_o4z_accounted(trace),
    msg="RUN O4z still-targeted block label hidden behind blanket no-op; trace=\{trace}",
  )
  match body {
    [
      @lib.Block(
        _,
        @lib.Expr([@lib.I32Const(_), @lib.If(_, [@lib.Br(_)], Some(_))])
      ),
    ] => ()
    other =>
      fail(
        "expected still-targeted block label to retarget through peel, got \{other}",
      )
  }
}

///|
test "remove-unused-names O4z accounts for live loop continue labels" {
  // RUN negative edge case: a loop with a surviving continue target is not a
  // dead-label loop, so the pass should run/account for it and leave it intact.
  let (body, trace) = remove_unused_names_o4z_run(
    "(module (func loop br 0 end))",
  )
  assert_true(
    remove_unused_names_o4z_accounted(trace),
    msg="RUN O4z live loop continue hidden behind blanket no-op; trace=\{trace}",
  )
  match body {
    [@lib.Loop(@lib.VoidBlockType, @lib.Expr([@lib.Br(@lib.LabelIdx(0))]))] =>
      ()
    other => fail("expected live-continue loop to remain, got \{other}")
  }
}

///|
test "remove-unused-names O4z accounts for try_table catch labels" {
  // RUN EH edge case: try_table catch targets are label uses and should be
  // retargeted when their old block target is peeled away.
  let (body, trace) = remove_unused_names_o4z_run(
    "(module (tag (param i32)) (func block block try_table (catch_all 0) nop end end end))",
  )
  assert_true(
    remove_unused_names_o4z_accounted(trace),
    msg="RUN O4z try_table catch label hidden behind blanket no-op; trace=\{trace}",
  )
  match body {
    [@lib.Block(_, @lib.Expr([@lib.TryTable(_, _, _)]))] => ()
    other =>
      fail(
        "expected try_table catch target to retarget through peel, got \{other}",
      )
  }
}

///|
test "remove-unused-names O4z accounts for type-mismatch loop demotion" {
  // RUN type edge case: this shape must not be hidden behind the blanket O4z
  // no-op. The current local representation keeps the typed unreachable loop
  // valid without requiring a separate O4z skip reason.
  let (body, trace) = remove_unused_names_o4z_run(
    "(module (func (result i32) loop (result i32) unreachable end))",
  )
  assert_true(
    remove_unused_names_o4z_accounted(trace),
    msg="RUN O4z type-mismatch loop hidden behind blanket no-op; trace=\{trace}",
  )
  match body {
    [@lib.Block(@lib.ValTypeBlockType(_), @lib.Expr([@lib.Unreachable]))] => ()
    other =>
      fail("expected type-mismatch loop demotion to remain valid, got \{other}")
  }
}

///|
test "remove-unused-names removes dropped unreachable debris before hard unreachable" {
  match
    remove_unused_names_test_body(
      "(module (type (func (param i64 i32) (result i64))) (func (type 0) (param i64 i32) (result i64) (local v128 v128 v128 v128) loop (result f32) unreachable unreachable end unreachable))",
    ) {
    [@lib.Unreachable] => ()
    other => fail("expected size-neutral unreachable cleanup, got \{other}")
  }
}

///|
test "remove-unused-names removes nested dropped unreachable debris before hard unreachable" {
  match
    remove_unused_names_test_body(
      "(module (type (func)) (type (func (result i32 i32))) (func (type 0) block (type 1) (result i32 i32) block (type 0) nop end unreachable end unreachable))",
    ) {
    [@lib.Nop, @lib.Unreachable] => ()
    other => fail("expected nested dropped unreachable cleanup, got \{other}")
  }
}

///|
test "remove-unused-names merges single-child same-typed nested blocks" {
  match
    remove_unused_names_test_body("(module (func block block nop end end))") {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr([]))] => ()
    other => fail("expected merged empty block, got \{other}")
  }
}

///|
test "remove-unused-names preserves type-index block wrappers while peeling" {
  match
    remove_unused_names_test_body(
      "(module (type (func (result i32))) (func (result i32) block (type 0) block (type 0) i32.const 7 end end))",
    ) {
    [
      @lib.Block(
        @lib.TypeIdxBlockType(@lib.TypeIdx(0)),
        @lib.Expr([@lib.I32Const(@lib.I32(7))])
      ),
    ] => ()
    other =>
      fail("expected peeled type-index block wrapper with value, got \{other}")
  }
}

///|
test "remove-unused-names retargets branches that originally escaped through peeled blocks" {
  match
    remove_unused_names_test_body(
      "(module (func block block block br 2 end end end))",
    ) {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr([@lib.Br(@lib.LabelIdx(0))]))] =>
      ()
    other =>
      fail("expected rebased branch to surviving outer block, got \{other}")
  }
}

///|
test "remove-unused-names retargets nested block branches when peeling equivalent wrappers" {
  match
    remove_unused_names_test_body(
      "(module (func block block i32.const 0 if br 1 else nop end end end))",
    ) {
    [
      @lib.Block(
        @lib.VoidBlockType,
        @lib.Expr(
          [
            @lib.I32Const(@lib.I32(0)),
            @lib.If(@lib.VoidBlockType, [@lib.Br(_)], Some(_)),
          ]
        )
      ),
    ] => ()
    other =>
      fail(
        "expected nested branch target to retarget through peeled block, got \{other}",
      )
  }
}

///|
test "remove-unused-names retargets try_table catches when peeling equivalent wrappers" {
  match
    remove_unused_names_test_body(
      "(module (tag (param i32)) (func block block try_table (catch_all 0) nop end end end))",
    ) {
    [
      @lib.Block(
        @lib.VoidBlockType,
        @lib.Expr(
          [
            @lib.TryTable(
              @lib.VoidBlockType,
              [@lib.CatchAll(@lib.LabelIdx(0))],
              @lib.Expr([])
            ),
          ]
        )
      ),
    ] => ()
    other =>
      fail(
        "expected try_table catch target to retarget through peeled block, got \{other}",
      )
  }
}

///|
test "remove-unused-names label-use helper marks delegate targets" {
  let func = @ir.HotFunc::new()
  let inner = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let target = @ir.hot_control_node_label(func, inner)
  let delegate = @ir.hot_build_delegate(func, target)
  @ir.hot_region_replace_body(func, @ir.hot_region_body_ref(func, inner), [
    delegate,
  ])
  let outer = @ir.hot_build_block(func, @lib.BlockType::void_(), [inner])
  @ir.hot_root_append(func, outer)
  @ir.hot_verify_all_or_abort(func)
  let label_used = pass_compute_label_used(func)
  assert_true(pass_label_is_used(target, label_used))
}

///|
test "remove-unused-names preserves non-label name-section metadata" {
  let non_label_name_sec = @lib.NameSec::new(
    func_names=Some(
      @lib.NameMap::new([
        @lib.NameAssoc::new(0U, @lib.Name::from_string("kept-func")),
      ]),
    ),
    local_names=Some(
      @lib.IndirectNameMap::new([
        @lib.IndirectNameAssoc::new(
          0U,
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("kept-local")),
          ]),
        ),
      ]),
    ),
  )
  let input = pass_test_module_from_wat(
    "(module (func (local i32) block block nop end end))",
  ).with_name_sec(non_label_name_sec)
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["remove-unused-names"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected name-section non-goal success, got \{err}")
  }
  @debug.assert_eq(optimized.name_sec, Some(non_label_name_sec))
}

///|
test "remove-unused-names drops stale label-name metadata after control rewrites" {
  let name_sec = @lib.NameSec::new(
    func_names=Some(
      @lib.NameMap::new([
        @lib.NameAssoc::new(0U, @lib.Name::from_string("kept-func")),
      ]),
    ),
    label_names=Some(
      @lib.IndirectNameMap::new([
        @lib.IndirectNameAssoc::new(
          0U,
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("stale-label")),
          ]),
        ),
      ]),
    ),
  )
  let input = pass_test_module_from_wat(
    "(module (func block block nop end end))",
  ).with_name_sec(name_sec)
  let optimized = match
    run_hot_pipeline(input, HotPipelineOptions::new(), ["remove-unused-names"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected label-name cleanup expectation success, got \{err}")
  }
  @debug.assert_eq(
    optimized.name_sec,
    Some(
      @lib.NameSec::new(
        func_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("kept-func")),
          ]),
        ),
      ),
    ),
  )
}

///|
test "remove-unused-names demotes loops without continue targets" {
  match remove_unused_names_test_body("(module (func loop nop end))") {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr([]))] => ()
    other => fail("expected loop to demote into an empty block, got \{other}")
  }
}

///|
test "remove-unused-names keeps loops with surviving continue targets" {
  match remove_unused_names_test_body("(module (func loop br 0 end))") {
    [@lib.Loop(@lib.VoidBlockType, @lib.Expr([@lib.Br(@lib.LabelIdx(0))]))] =>
      ()
    other =>
      fail("expected loop with continue edge to remain a loop, got \{other}")
  }
}
