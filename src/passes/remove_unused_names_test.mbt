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
test "remove-unused-names merges single-child same-typed nested blocks" {
  match
    remove_unused_names_test_body("(module (func block block nop end end))") {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr([@lib.Nop]))] => ()
    other => fail("expected merged single block, got \{other}")
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
test "remove-unused-names demotes loops without continue targets" {
  match remove_unused_names_test_body("(module (func loop nop end))") {
    [@lib.Block(@lib.VoidBlockType, @lib.Expr([@lib.Nop]))] => ()
    other => fail("expected loop to demote into a block, got \{other}")
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
