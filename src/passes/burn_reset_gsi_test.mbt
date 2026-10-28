///|
fn burn_reset_gsi_check_host_origin(input : String) -> Unit raise {
  let mod_ = match @wast.wast_to_binary_module(input) {
    Ok(mod_) => mod_
    Err(err) => fail("fixture parse failed: \{err}")
  }
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) => fail("fixture validation failed: \{err}")
  }
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(closed_world=true), [
      "global-struct-inference",
    ]) {
    Ok(mod_) => mod_
    Err(err) => fail("pipeline failed: \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => ()
    Err(err) => fail("output validation failed: \{err}")
  }
  let @lib.Func(_, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  // Host writes can supply any compatible struct. The private singleton must
  // never replace the object read from the exported mutable resource.
  assert_eq(
    audit_count(body, fn(instr) { instr is @lib.GlobalGet(@lib.GlobalIdx(0U)) }),
    0,
  )
}

///|
test "burn reset GSI preserves object read from exported mutable global" {
  burn_reset_gsi_check_host_origin(
    (
      #| (module
      #|   (type $S (struct (field i32)))
      #|   (global $one (ref $S) (struct.new $S (i32.const 1)))
      #|   (global $in (export "input") (mut (ref null $S)) (ref.null $S))
      #|   (func (export "run") (result i32) (local (ref null $S))
      #|     global.get $in
      #|     local.set 0
      #|     local.get 0
      #|     struct.get $S 0))
    ),
  )
}

///|
test "burn reset GSI preserves object read from exported struct table" {
  burn_reset_gsi_check_host_origin(
    (
      #| (module
      #|   (type $S (struct (field i32)))
      #|   (global $one (ref $S) (struct.new $S (i32.const 1)))
      #|   (table (export "input") 1 (ref null $S))
      #|   (func (export "run") (result i32) (local (ref null $S))
      #|     i32.const 0
      #|     table.get 0
      #|     local.set 0
      #|     local.get 0
      #|     struct.get $S 0))
    ),
  )
}
