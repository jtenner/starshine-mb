///|
fn gr_test_defined_global_type(
  mod_ : @lib.Module,
  defined_idx : Int,
) -> @lib.GlobalType raise {
  match mod_.global_sec {
    Some(@lib.GlobalSec(globals)) =>
      match globals.get(defined_idx) {
        Some(@lib.Global(global_type, _)) => global_type
        None => fail("expected defined global \{defined_idx}")
      }
    None => fail("expected global section")
  }
}

///|
test "run_hot_pipeline applies global-refining to private globals with narrower writes" {
  let input =
    #| (module
    #|   (type $base (sub (struct)))
    #|   (type $child (sub $base (struct)))
    #|   (global $g (mut (ref null $base)) (ref.null $child))
    #|   (func (export "set")
    #|     ref.null $child
    #|     global.set $g)
    #|   (func (export "get") (result (ref null $base))
    #|     global.get $g))
    #|
  let optimized = match pass_test_run_pipeline(input, ["global-refining"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected global-refining pipeline success, got \{err}")
  }

  assert_eq(
    try! gr_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(1U))),
      ),
      true,
    ),
  )
}

///|
test "global-refining keeps exported globals at their declared boundary type" {
  let input =
    #| (module
    #|   (type $base (sub (struct)))
    #|   (type $child (sub $base (struct)))
    #|   (global $g (export "g") (mut (ref null $base)) (ref.null $child))
    #|   (func (export "set")
    #|     ref.null $child
    #|     global.set $g))
    #|
  let optimized = match pass_test_run_pipeline(input, ["global-refining"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected exported global-refining success, got \{err}")
  }

  assert_eq(
    try! gr_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
      ),
      true,
    ),
  )
}

///|
test "global-refining joins sibling writes at the shared declared supertype" {
  let input =
    #| (module
    #|   (type $base (sub (struct)))
    #|   (type $left (sub $base (struct)))
    #|   (type $right (sub $base (struct)))
    #|   (global $g (mut anyref) (ref.null $left))
    #|   (func (export "flip") (param i32)
    #|     local.get 0
    #|     if
    #|       ref.null $left
    #|       global.set $g
    #|     else
    #|       ref.null $right
    #|       global.set $g
    #|     end))
    #|
  let optimized = match pass_test_run_pipeline(input, ["global-refining"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected sibling global-refining success, got \{err}")
  }

  assert_eq(
    try! gr_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
      ),
      true,
    ),
  )
}
