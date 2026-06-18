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

  @debug.assert_eq(
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
test "global-refining refines exported immutable globals from their initializer" {
  let input =
    #| (module
    #|   (global $g (export "g") exnref (ref.null exn)))
  let optimized = match pass_test_run_pipeline(input, ["global-refining"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected exported immutable global-refining success, got \{err}")
  }

  @debug.assert_eq(
    try! gr_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::no_exn())),
      ),
      false,
    ),
  )
}

///|
test "global-refining keeps exported mutable globals at their declared boundary type" {
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

  @debug.assert_eq(
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
test "global-refining treats abstract ref.null initializers as bottom references" {
  let input =
    #| (module
    #|   (global $exn (mut exnref) (ref.null exn))
    #|   (global $extern (mut externref) (ref.null extern))
    #|   (global $func (mut funcref) (ref.null func))
    #|   (global $any (mut anyref) (ref.null any)))
  let optimized = match pass_test_run_pipeline(input, ["global-refining"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ref.null global-refining success, got \{err}")
  }

  @debug.assert_eq(
    try! gr_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::no_exn())),
      ),
      true,
    ),
  )
  @debug.assert_eq(
    try! gr_test_defined_global_type(optimized, 1),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(
          true,
          @lib.HeapType::abs(@lib.AbsHeapType::no_extern()),
        ),
      ),
      true,
    ),
  )
  @debug.assert_eq(
    try! gr_test_defined_global_type(optimized, 2),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::no_func())),
      ),
      true,
    ),
  )
  @debug.assert_eq(
    try! gr_test_defined_global_type(optimized, 3),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::none())),
      ),
      true,
    ),
  )
}

///|
test "global-refining refines private ref.func initializers to exact function heap types" {
  let input =
    #| (module
    #|   (type $f_t (func))
    #|   (func $f (type $f_t))
    #|   (elem declare func $f)
    #|   (global $g (mut funcref) (ref.func $f)))
  let optimized = match pass_test_run_pipeline(input, ["global-refining"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected ref.func global-refining success, got \{err}")
  }

  @debug.assert_eq(
    try! gr_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(
          false,
          @lib.HeapType::new(@lib.TypeIdx::new(0U)),
          exact=true,
        ),
      ),
      true,
    ),
  )
}

///|
test "global-refining joins ref.null func initializers with exact ref.func writes" {
  let input =
    #| (module
    #|   (type $f_t (func))
    #|   (global $g (mut funcref) (ref.null func))
    #|   (func $f (type $f_t)
    #|     ref.func $f
    #|     global.set $g)
    #|   (elem declare func $f))
  let optimized = match pass_test_run_pipeline(input, ["global-refining"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected null plus ref.func global-refining success, got \{err}")
  }

  @debug.assert_eq(
    try! gr_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(
          true,
          @lib.HeapType::new(@lib.TypeIdx::new(0U)),
          exact=true,
        ),
      ),
      true,
    ),
  )
}

///|
test "global-refining preserves exact ref.func LUB across nullable writes" {
  let input =
    #| (module
    #|   (type $f_t (func))
    #|   (global $g (mut funcref) (ref.func $f))
    #|   (func $f (type $f_t)
    #|     ref.null func
    #|     global.set $g)
    #|   (elem declare func $f))
  let optimized = match pass_test_run_pipeline(input, ["global-refining"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected ref.func plus null global-refining success, got \{err}")
  }

  @debug.assert_eq(
    try! gr_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(
          true,
          @lib.HeapType::new(@lib.TypeIdx::new(0U)),
          exact=true,
        ),
      ),
      true,
    ),
  )
}

///|
test "global-refining keeps non-null ref.func initializer and writes exact" {
  let input =
    #| (module
    #|   (type $f_t (func))
    #|   (global $g (mut funcref) (ref.func $f))
    #|   (func $f (type $f_t)
    #|     ref.func $f
    #|     global.set $g)
    #|   (elem declare func $f))
  let optimized = match pass_test_run_pipeline(input, ["global-refining"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected non-null ref.func global-refining success, got \{err}")
  }

  @debug.assert_eq(
    try! gr_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(
          false,
          @lib.HeapType::new(@lib.TypeIdx::new(0U)),
          exact=true,
        ),
      ),
      true,
    ),
  )
}

///|
test "global-refining ref.func subtype LUB keeps the exact subtype" {
  let input =
    #| (module
    #|   (type $super (sub (func)))
    #|   (type $sub (sub $super (func)))
    #|   (global $a (ref $super) (ref.func $f))
    #|   (func $f (type $sub))
    #|   (elem declare func $f))
  let optimized = match pass_test_run_pipeline(input, ["global-refining"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected subtype ref.func global-refining success, got \{err}")
  }

  @debug.assert_eq(
    try! gr_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(
          false,
          @lib.HeapType::new(@lib.TypeIdx::new(1U)),
          exact=true,
        ),
      ),
      false,
    ),
  )
}

///|
test "global-refining refines private i31 const-expression initializers" {
  let input =
    #| (module
    #|   (global $g (mut anyref) (ref.i31 (i32.const 7))))
  let optimized = match pass_test_run_pipeline(input, ["global-refining"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected i31 initializer global-refining success, got \{err}")
  }

  @debug.assert_eq(
    try! gr_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(false, @lib.HeapType::abs(@lib.AbsHeapType::i31())),
      ),
      true,
    ),
  )
}

///|
test "global-refining refines private struct default initializers" {
  let input =
    #| (module
    #|   (type $s (sub (struct)))
    #|   (global $g (mut anyref) (struct.new_default $s)))
  let optimized = match pass_test_run_pipeline(input, ["global-refining"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected struct initializer global-refining success, got \{err}")
  }

  @debug.assert_eq(
    try! gr_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(
          false,
          @lib.HeapType::new(@lib.TypeIdx::new(0U)),
          exact=true,
        ),
      ),
      true,
    ),
  )
}

///|
test "global-refining keeps exported immutable exact private initializers public" {
  let input =
    #| (module
    #|   (type $s (sub (struct)))
    #|   (global $g (export "g") anyref (struct.new_default $s)))
  let optimized = match pass_test_run_pipeline(input, ["global-refining"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected exported exact global-refining success, got \{err}")
  }

  @debug.assert_eq(
    try! gr_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::any())),
      ),
      false,
    ),
  )
}

///|
test "global-refining still runs in the O4z direct pass slot" {
  let input =
    #| (module
    #|   (global $g (mut exnref) (ref.null exn)))
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["global-refining"],
      options=HotPipelineOptions::new(optimize_level=4, shrink_level=1),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected O4z global-refining success, got \{err}")
  }

  @debug.assert_eq(
    try! gr_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::no_exn())),
      ),
      true,
    ),
  )
}

///|
test "global-refining preserves exported globals in closed world" {
  let input =
    #| (module
    #|   (global $g (export "g") exnref (ref.null exn)))
  let optimized = match
    pass_test_run_pipeline(
      input,
      ["global-refining"],
      options=HotPipelineOptions::new(closed_world=true),
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected closed-world exported global-refining success, got \{err}")
  }

  @debug.assert_eq(
    try! gr_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::exn())),
      ),
      false,
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

  @debug.assert_eq(
    try! gr_test_defined_global_type(optimized, 0),
    @lib.GlobalType::new(
      @lib.ValType::ref_type(
        @lib.RefType::new(true, @lib.HeapType::new(@lib.TypeIdx::new(0U))),
      ),
      true,
    ),
  )
}
