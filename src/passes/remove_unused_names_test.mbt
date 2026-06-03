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
test "remove-unused-names skips O4z raw pass until self-opt encoder stack is safe" {
  let trace : Array[String] = []
  match
    pass_test_run_pipeline(
      "(module (func (block (block))))",
      ["remove-unused-names"],
      options=HotPipelineOptions::new(
        optimize_level=4,
        shrink_level=1,
        trace=Some(fn(line) { trace.push(line) }),
      ),
    ) {
    Ok(_) => ()
    Err(err) =>
      fail("expected O4z remove-unused-names skip success, got \{err}")
  }
  assert_true(
    trace.any(fn(line) {
      line.contains(
        "pass[remove-unused-names]:skip-raw reason=o4z-remove-unused-names-noop",
      )
    }),
  )
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
test "remove-unused-names keeps nested blocks when a nested control still targets a peeled scope" {
  match
    remove_unused_names_test_body(
      "(module (func block block i32.const 0 if br 1 else nop end end end))",
    ) {
    [
      @lib.Block(
        @lib.VoidBlockType,
        @lib.Expr(
          [
            @lib.Block(
              @lib.VoidBlockType,
              @lib.Expr(
                [
                  @lib.I32Const(@lib.I32(0)),
                  @lib.If(
                    @lib.VoidBlockType,
                    [@lib.Br(@lib.LabelIdx(1))],
                    Some([@lib.Nop])
                  ),
                ]
              )
            ),
          ]
        )
      ),
    ] => ()
    other =>
      fail("expected nested block bailout shape to remain intact, got \{other}")
  }
}

///|
test "remove-unused-names keeps nested blocks when try_table catches still target a peeled scope" {
  match
    remove_unused_names_test_body(
      "(module (tag (param i32)) (func block block try_table (catch_all 0) nop end end end))",
    ) {
    [
      @lib.Block(
        @lib.VoidBlockType,
        @lib.Expr(
          [
            @lib.Block(
              @lib.VoidBlockType,
              @lib.Expr(
                [
                  @lib.TryTable(
                    @lib.VoidBlockType,
                    [@lib.CatchAll(@lib.LabelIdx(0))],
                    @lib.Expr([@lib.Nop])
                  ),
                ]
              )
            ),
          ]
        )
      ),
    ] => ()
    other =>
      fail(
        "expected try_table catch-target bailout shape to remain intact, got \{other}",
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
