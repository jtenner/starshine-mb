///|
test "no-write cleanup avoids redundant root scans while preserving nested rewrites" {
  for mode in 0..<3 {
    let leaves = Array::makei(32, fn(local) {
      match mode {
        0 => "local.get 0 i32.const 1 i32.add drop"
        1 => "block local.get 0 drop end"
        _ =>
          "block i32.const 7 local.set \{local + 1} local.get \{local + 1} drop end"
      }
    }).join(" ")
    let locals = Array::make(32, "i32").join(" ")
    let input = pass_test_module_from_wat(
      "(module (func (param i32) (local \{locals}) \{leaves}))",
    )
    let saved = @binary.encode_module(input).unwrap()
    let @lib.Func(local_types, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let visits = [0]
    let actual = sl_cleanup_drop_dead_pairs_with_reads(
      body,
      SlCleanupReadSet::new([]),
      cleanup_root_visits=Some(visits),
    )
    assert_eq(
      actual,
      sl_cleanup_nowrite_reference(body, SlCleanupReadSet::new([])),
    )
    assert_eq(physical_equal(actual, body), mode != 2)
    @validate.validate_module(
      input.with_code_sec(
        @lib.CodeSec::new([@lib.Func::new(local_types, @lib.Expr::new(actual))]),
      ),
    ).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    assert_true(
      visits[0] <= body.length() * (if mode == 0 { 1 } else { 2 }),
      msg="redundant root visits: \{visits[0]}",
    )
  }
}

///|
test "root admission retains effects GC reads and legacy scopes" {
  for
    wat in [
      "(module (import \"env\" \"effect\" (func $effect (param i32))) (func (param i32) local.get 0 call $effect))",
      "(module (type $t (struct (field i32))) (func (param (ref $t)) local.get 0 drop))",
      "(module (func (param i32) (try (do local.get 0 drop) (catch_all local.get 0 drop))))",
      "(module (func (param i32) block local.get 0 drop end local.get 0 drop))",
    ] {
    let input = pass_test_module_from_wat(wat)
    let saved = @binary.encode_module(input).unwrap()
    let @lib.Func(local_types, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    let actual = sl_cleanup_drop_dead_pairs_with_reads(
      body,
      SlCleanupReadSet::new([]),
    )
    assert_eq(
      actual,
      sl_cleanup_nowrite_reference(body, SlCleanupReadSet::new([])),
    )
    assert_true(physical_equal(actual, body))
    @validate.validate_module(
      input.with_code_sec(
        @lib.CodeSec::new([@lib.Func::new(local_types, @lib.Expr::new(actual))]),
      ),
    ).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
