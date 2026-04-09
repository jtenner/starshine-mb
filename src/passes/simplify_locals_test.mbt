///|
fn simplify_locals_run_hot(text : String) -> @ir.HotFunc {
  let func = pass_test_lift_first_func(text)
  let ctx = HotPassContext::new(
    simplify_locals_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => func
    Err(err) => abort("unexpected simplify-locals hot test failure: \{err}")
  }
}

///|
fn simplify_locals_run_hot_rounds(text : String, rounds : Int) -> @ir.HotFunc {
  let func = pass_test_lift_first_func(text)
  for _ in 0..<rounds {
    let ctx = HotPassContext::new(
      simplify_locals_descriptor(),
      @ir.HotAnalysisCache::new(),
      HotPipelineVerifyPolicy::after_each_pass(),
      false,
      fn(_) { () },
    )
    match hot_pass_run(ctx, func) {
      Ok(_) => ()
      Err(err) => abort("unexpected simplify-locals hot test failure: \{err}")
    }
  }
  func
}

///|
test "simplify-locals rewrites dead local.set roots" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 1 local.set 0 i32.const 7))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set"))
  assert_false(pretty.contains("drop"))
  assert_true(pretty.contains("I32(7)"))
}

///|
test "simplify-locals rewrites dead local.tee roots" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 1 local.tee 0 drop i32.const 7))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.tee"))
  assert_false(pretty.contains("drop"))
  assert_true(pretty.contains("I32(7)"))
}

///|
test "simplify-locals skips unreachable local defs outside the ssa overlay" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) block unreachable i32.const 1 local.set 0 end i32.const 7))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected unreachable simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(7)"))
}

///|
test "simplify-locals rewrites dead pure local.set roots to nop" {
  let func = simplify_locals_run_hot(
    "(module (func (local i32) i32.const 861 local.set 0 f32.const 65 drop))",
  )

  match @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op {
    @ir.HotOp::Nop => ()
    op => fail("expected nop root after pure dead local.set, got \{op}")
  }
  match @ir.hot_node_get(func, @ir.hot_root_get(func, 1)).op {
    @ir.HotOp::Drop => ()
    op => fail("expected trailing drop root, got \{op}")
  }
}

///|
test "simplify-locals keeps drops for dead side-effectful local.set roots" {
  let func = simplify_locals_run_hot(
    "(module (func (local i32) call 1 local.set 0) (func (result i32) i32.const 7))",
  )

  match @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op {
    @ir.HotOp::Drop => ()
    op =>
      fail("expected drop root for side-effectful dead local.set, got \{op}")
  }
}

///|
test "simplify-locals keeps dead local.sets when the local is still read elsewhere" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i32) (local i32) i32.const 1 local.set 0 i32.const 2 local.set 0 local.get 0))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail(
        "expected conservative dead local.set simplify-locals success, got \{err}",
      )
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("I32(1)"))
  assert_true(pretty.contains("I32(2)"))
}

///|
test "simplify-locals keeps shared tee children that remain referenced" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let shared = @ir.hot_build_const_i32(func, @lib.I32(1))
  let tee = @ir.hot_build_local_tee(func, 0, shared)
  let drop_tee = @ir.hot_build_drop(func, tee)
  let drop_shared = @ir.hot_build_drop(func, shared)
  @ir.hot_root_append(func, drop_tee)
  @ir.hot_root_append(func, drop_shared)
  let ctx = HotPassContext::new(
    simplify_locals_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected simplify-locals shared-child success, got \{err}")
  }

  assert_true(@ir.hot_node_is_live(func, shared))
}

///|
test "simplify-locals rewrites dead pure local.tee drop roots to nop" {
  let func = simplify_locals_run_hot(
    "(module (func (local i64) i64.const 756 local.tee 0 drop i32.const 7 drop))",
  )

  match @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op {
    @ir.HotOp::Nop => ()
    op => fail("expected nop root after pure dead local.tee, got \{op}")
  }
  match @ir.hot_node_get(func, @ir.hot_root_get(func, 1)).op {
    @ir.HotOp::Drop => ()
    op => fail("expected trailing drop root, got \{op}")
  }
}

///|
test "simplify-locals forwards pure local.tee values into the lone later local.get" {
  let func = simplify_locals_run_hot(
    "(module (func (result f64) (local f64) f64.const 39 local.tee 0 drop local.get 0))",
  )

  match @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op {
    @ir.HotOp::Nop => ()
    op => fail("expected nop root after forwarded pure local.tee, got \{op}")
  }
  match @ir.hot_node_get(func, @ir.hot_root_get(func, 1)).op {
    @ir.HotOp::Const => ()
    op => fail("expected const root after forwarded pure local.get, got \{op}")
  }
}

///|
test "simplify-locals rehomes dead tee control labels before cleanup" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let carried_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
  )
  let carried_label = @ir.hot_control_node_label(func, carried_block)
  let tee = @ir.hot_build_local_tee(func, 0, carried_block)
  let drop_tee = @ir.hot_build_drop(func, tee)
  @ir.hot_root_append(func, drop_tee)
  @ir.hot_root_append(func, @ir.hot_build_const_i32(func, @lib.I32(7)))
  let ctx = HotPassContext::new(
    simplify_locals_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )

  match hot_pass_run(ctx, func) {
    Ok(_) => ()
    Err(err) =>
      fail("expected simplify-locals dead-tee control success, got \{err}")
  }

  match @ir.hot_node_get(func, tee).op {
    @ir.HotOp::Block => ()
    other => fail("expected tee slot to become a block, got \{other}")
  }
  assert_eq(@ir.hot_control_node_label(func, tee), carried_label)
  assert_eq(@ir.hot_label_owner(func, carried_label), tee)
  assert_false(@ir.hot_node_is_live(func, carried_block))
  match @ir.hot_verify_core(func) {
    Ok(_) => ()
    Err(err) =>
      fail(
        "expected simplify-locals dead-tee control verify success, got \{err}",
      )
  }
}

///|
test "simplify-locals forwards pure local.set values into the lone later local.get" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (result i64) (local i64 i32) i32.const 143 local.tee 1 drop i32.const 0 if nop else nop end i32.const 379 local.tee 1 drop i64.const 885 local.set 0 local.get 0))",
      ["simplify-locals"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected forwarded local.set simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set"))
  assert_false(pretty.contains("local.get"))
  assert_true(pretty.contains("I64(885)"))
}

///|
test "simplify-locals rewrites same-local result-if storeback roots into conditional updates" {
  let func = simplify_locals_run_hot(
    "(module (func (param i32 i32) (result i32) (local.set 0 (if (result i32) (local.get 1) (then (i32.const 2)) (else (local.get 0)))) (local.get 0)))",
  )

  let rewritten = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, rewritten).op {
    @ir.HotOp::If => ()
    op => fail("expected storeback root to become if, got \{op}")
  }
  let then_region = @ir.hot_region_then_ref(func, rewritten)
  assert_eq(@ir.hot_region_root_count(func, then_region), 1)
  let then_root = @ir.hot_region_get(func, then_region, 0)
  match @ir.hot_node_get(func, then_root).op {
    @ir.HotOp::LocalSet => ()
    op => fail("expected then root to store the updated value, got \{op}")
  }
  let else_region = @ir.hot_region_else_ref(func, rewritten).unwrap()
  assert_eq(@ir.hot_region_root_count(func, else_region), 0)
}

///|
test "simplify-locals keeps terminal if tails as a blocked frontier" {
  let func = simplify_locals_run_hot(
    "(module (func (param i32) (result i32) (local i32 i32) (if (local.get 0) (then (return (i32.const 7)))) (local.set 1 (i32.const 3)) (local.set 2 (i32.add (local.get 1) (i32.const 1))) (local.get 2)))",
  )

  assert_eq(@ir.hot_root_count(func), 4)
  let frontier = @ir.hot_root_get(func, 0)
  match @ir.hot_node_get(func, frontier).op {
    @ir.HotOp::If => ()
    op => fail("expected frontier root 0 to remain if, got \{op}")
  }
  match @ir.hot_node_get(func, @ir.hot_root_get(func, 1)).op {
    @ir.HotOp::Nop => ()
    op => fail("expected frontier root 1 to become nop, got \{op}")
  }
  match @ir.hot_node_get(func, @ir.hot_root_get(func, 2)).op {
    @ir.HotOp::LocalSet => ()
    op => fail("expected frontier root 2 to remain local.set, got \{op}")
  }
}

///|
test "simplify-locals forwards result-if producer sets into immediate later uses" {
  let func = simplify_locals_run_hot(
    "(module (func (param i32) (result i32) (local i32) (local.set 1 (if (result i32) (local.get 0) (then (i32.const 4)) (else (i32.const 9)))) (i32.add (local.get 1) (i32.const 1))))",
  )

  match @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op {
    @ir.HotOp::Nop => ()
    op => fail("expected producer root to become nop, got \{op}")
  }
  let use_root = @ir.hot_root_get(func, 1)
  match @ir.hot_node_get(func, @ir.hot_child_get(func, use_root, 0)).op {
    @ir.HotOp::If => ()
    op =>
      fail("expected immediate use root to inline the producer if, got \{op}")
  }
}

///|
test "simplify-locals rewrites result-if producer sets into immediate tees when later reads still need the local" {
  let func = simplify_locals_run_hot(
    "(module (func (param i32) (result i32) (local i32) (local.set 1 (if (result i32) (local.get 0) (then (i32.const 4)) (else (i32.const 9)))) (drop (i32.add (local.get 1) (i32.const 1))) (local.get 1)))",
  )

  match @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op {
    @ir.HotOp::Nop => ()
    op => fail("expected producer root to become nop, got \{op}")
  }
  let use_root = @ir.hot_root_get(func, 1)
  let add_id = @ir.hot_child_get(func, use_root, 0)
  match @ir.hot_node_get(func, @ir.hot_child_get(func, add_id, 0)).op {
    @ir.HotOp::LocalTee => ()
    op =>
      fail(
        "expected immediate use to rewrite to local.tee while later reads still need the local, got \{op}",
      )
  }
}

///|
test "simplify-locals rewrites pure producer sets into immediate tees when later reads still need the local" {
  let func = simplify_locals_run_hot(
    "(module (func (param i32) (result i32) (local i32) (local.set 1 (i32.sub (i32.const 31) (i32.clz (local.get 0)))) (drop (i32.shr_u (i32.const 64) (local.get 1))) (local.get 1)))",
  )

  match @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op {
    @ir.HotOp::Nop => ()
    op => fail("expected pure producer root to become nop, got \{op}")
  }
  let use_root = @ir.hot_root_get(func, 1)
  let shr_id = @ir.hot_child_get(func, use_root, 0)
  match @ir.hot_node_get(func, @ir.hot_child_get(func, shr_id, 1)).op {
    @ir.HotOp::LocalTee => ()
    op =>
      fail(
        "expected pure immediate use to rewrite to local.tee while later reads still need the local, got \{op}",
      )
  }
}

///|
test "simplify-locals keeps the live multi-root storeback extraction frontier" {
  let func = simplify_locals_run_hot(
    "(module (func (param i32) (result i32) (local i32 i32) (local.set 1 (if (result i32) (local.get 0) (then (nop) (i32.sub (i32.add (local.get 1) (i32.shl (i32.const 1) (i32.sub (i32.const 27) (i32.clz (local.get 1))))) (i32.const 1))) (else (local.get 1)))) (local.set 2 (i32.sub (i32.const 31) (i32.clz (local.get 1)))) (local.set 1 (i32.xor (i32.shr_u (local.get 1) (i32.sub (local.get 2) (i32.const 4))) (i32.const 16))) (i32.sub (local.get 2) (i32.const 7))))",
  )

  match @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op {
    @ir.HotOp::If => ()
    op => fail("expected live frontier root 0 to become if, got \{op}")
  }
  match @ir.hot_node_get(func, @ir.hot_root_get(func, 1)).op {
    @ir.HotOp::LocalSet => ()
    op => fail("expected live frontier root 1 to remain local.set, got \{op}")
  }
  match @ir.hot_node_get(func, @ir.hot_root_get(func, 2)).op {
    @ir.HotOp::LocalSet => ()
    op => fail("expected live frontier root 2 to remain local.set, got \{op}")
  }
}

///|
test "simplify-locals keeps the live multi-root storeback extraction frontier after two rounds" {
  let func = simplify_locals_run_hot_rounds(
    "(module (func (param i32) (result i32) (local i32 i32) (local.set 1 (if (result i32) (local.get 0) (then (nop) (i32.sub (i32.add (local.get 1) (i32.shl (i32.const 1) (i32.sub (i32.const 27) (i32.clz (local.get 1))))) (i32.const 1))) (else (local.get 1)))) (local.set 2 (i32.sub (i32.const 31) (i32.clz (local.get 1)))) (local.set 1 (i32.xor (i32.shr_u (local.get 1) (i32.sub (local.get 2) (i32.const 4))) (i32.const 16))) (i32.sub (local.get 2) (i32.const 7))))",
    2,
  )

  match @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op {
    @ir.HotOp::If => ()
    op =>
      fail("expected two-round live frontier root 0 to remain if, got \{op}")
  }
  match @ir.hot_node_get(func, @ir.hot_root_get(func, 1)).op {
    @ir.HotOp::LocalSet => ()
    op =>
      fail(
        "expected two-round live frontier root 1 to remain local.set, got \{op}",
      )
  }
  match @ir.hot_node_get(func, @ir.hot_root_get(func, 2)).op {
    @ir.HotOp::LocalSet => ()
    op =>
      fail(
        "expected two-round live frontier root 2 to remain local.set, got \{op}",
      )
  }
}

///|
test "simplify-locals keeps structured producer sets when immediate use has an impure prefix" {
  let func = simplify_locals_run_hot(
    "(module (func (param i32) (result i32) (local i32) (local.set 1 (if (result i32) (local.get 0) (then (i32.const 4)) (else (i32.const 9)))) (i32.add (call 1) (local.get 1))) (func (result i32) (i32.const 7)))",
  )

  match @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op {
    @ir.HotOp::LocalSet => ()
    op => fail("expected producer root to remain local.set, got \{op}")
  }
  let use_root = @ir.hot_root_get(func, 1)
  match @ir.hot_node_get(func, @ir.hot_child_get(func, use_root, 1)).op {
    @ir.HotOp::LocalGet => ()
    op => fail("expected impure-prefix use root to keep local.get, got \{op}")
  }
}

///|
test "simplify-locals keeps result-if producer sets with nested explicit exits" {
  let func = simplify_locals_run_hot(
    "(module (func (param i32) (result i32) (local i32) (local.set 1 (if (result i32) (local.get 0) (then (block (result i32) (br 0 (i32.const 4)))) (else (i32.const 9)))) (i32.add (local.get 1) (i32.const 1))))",
  )

  match @ir.hot_node_get(func, @ir.hot_root_get(func, 0)).op {
    @ir.HotOp::LocalSet => ()
    op =>
      fail(
        "expected explicit-exit producer root to remain local.set, got \{op}",
      )
  }
  let use_root = @ir.hot_root_get(func, 1)
  match @ir.hot_node_get(func, @ir.hot_child_get(func, use_root, 0)).op {
    @ir.HotOp::LocalGet => ()
    op =>
      fail(
        "expected explicit-exit immediate use root to keep local.get, got \{op}",
      )
  }
}

///|
test "simplify-locals rewrites dead local.tee roots with structured children" {
  let source =
    #|(module
    #|  (func (param i32) (result i32)
    #|    (local i32)
    #|    (block (result i32)
    #|      (if (result i32)
    #|        (local.get 0)
    #|        (then
    #|          (i32.const 1))
    #|        (else
    #|          (i32.const 2))))
    #|    (local.tee 1)
    #|    drop
    #|    (i32.const 7)))
    #|
  let optimized = match pass_test_run_pipeline(source, ["simplify-locals"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected structured-child simplify-locals success, got \{err}")
  }

  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.tee"))
  assert_true(pretty.contains("I32(7)"))
}
