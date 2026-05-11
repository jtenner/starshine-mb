///|
fn rse_test_run_hot(text : String) -> @ir.HotFunc {
  let func = pass_test_lift_first_func(text)
  let ctx = HotPassContext::new(
    rse_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  match hot_pass_run(ctx, func) {
    Ok(_) => func
    Err(err) => abort("expected rse hot pass success, got \{err}")
  }
}

///|
fn rse_expect_op(func : @ir.HotFunc, node_id : Int, expected : String) -> Unit {
  let op = @ir.hot_node_get(func, node_id).op
  match expected {
    "local.set" =>
      match op {
        @ir.HotOp::LocalSet => ()
        other => abort("expected local.set, got \{other}")
      }
    "drop" =>
      match op {
        @ir.HotOp::Drop => ()
        other => abort("expected drop, got \{other}")
      }
    "const" =>
      match op {
        @ir.HotOp::Const => ()
        other => abort("expected const, got \{other}")
      }
    "local.get" =>
      match op {
        @ir.HotOp::LocalGet => ()
        other => abort("expected local.get, got \{other}")
      }
    _ => abort("unknown expected op")
  }
}

///|
test "rse replaces same-value local.set shell with drop" {
  let func = rse_test_run_hot(
    "(module (func (local i32) i32.const 1 local.set 0 i32.const 1 local.set 0))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  rse_expect_op(func, @ir.hot_root_get(func, 0), "local.set")
  let rewritten = @ir.hot_root_get(func, 1)
  rse_expect_op(func, rewritten, "drop")
  rse_expect_op(func, @ir.hot_child_get(func, rewritten, 0), "const")
}

///|
test "rse replaces same-value local.tee shell with its value" {
  let func = rse_test_run_hot(
    "(module (func (local i32) i32.const 1 local.set 0 i32.const 1 local.tee 0 drop))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  rse_expect_op(func, @ir.hot_root_get(func, 0), "local.set")
  let drop = @ir.hot_root_get(func, 1)
  rse_expect_op(func, drop, "drop")
  rse_expect_op(func, @ir.hot_child_get(func, drop, 0), "const")
}

///|
test "rse keeps different overwritten values" {
  let func = rse_test_run_hot(
    "(module (func (local i32) i32.const 1 local.set 0 i32.const 2 local.set 0))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  rse_expect_op(func, @ir.hot_root_get(func, 0), "local.set")
  rse_expect_op(func, @ir.hot_root_get(func, 1), "local.set")
}

///|
test "rse treats branch disagreement as a merge value for self sets" {
  let func = rse_test_run_hot(
    "(module (func (param i32) (local i32) local.get 0 if i32.const 1 local.set 1 else i32.const 2 local.set 1 end local.get 1 local.set 1))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  let rewritten = @ir.hot_root_get(func, 1)
  rse_expect_op(func, rewritten, "drop")
  rse_expect_op(func, @ir.hot_child_get(func, rewritten, 0), "local.get")
}

///|
fn rse_test_first_defined_func(mod_ : @lib.Module) -> @lib.Func {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs.get(0) {
        Some(func) => func
        None => abort("expected first defined function")
      }
    None => abort("expected code section")
  }
}

///|
fn rse_test_run_module(mod_ : @lib.Module) -> @lib.Module {
  match @validate.validate_module(mod_) {
    Ok(_) => ()
    Err(err) => abort("unexpected invalid rse fixture: \{err}")
  }
  let optimized = match
    run_hot_pipeline(mod_, HotPipelineOptions::new(), [
      "redundant-set-elimination",
    ]) {
    Ok(mod_) => mod_
    Err(err) => abort("expected rse pipeline success, got \{err}")
  }
  match @validate.validate_module(optimized) {
    Ok(_) => optimized
    Err(err) => abort("expected rse output to validate, got \{err}")
  }
}

///|
fn rse_test_refined_cast_module(cast : @lib.Instruction) -> @lib.Module {
  let base_idx = @lib.TypeIdx::new(0U)
  let base_heap = @lib.HeapType::new(base_idx)
  let nullable_base_ref = @lib.ValType::ref_type(
    @lib.RefType::new(true, base_heap),
  )
  let base_ref = @lib.ValType::ref_type(@lib.RefType::new(false, base_heap))
  let base = @lib.RecType::new(
    @lib.SubType::new(false, [], @lib.CompType::struct_([])),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([nullable_base_ref, base_ref], []),
    ),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([base, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(1U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::new([]),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          cast,
          @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::drop(),
          @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
          @lib.Instruction::drop(),
        ]),
      ),
    ]),
  )
}

///|
fn rse_test_needs_refinalize_module() -> @lib.Module {
  let a_idx = @lib.TypeIdx::new(0U)
  let b_idx = @lib.TypeIdx::new(1U)
  let a_heap = @lib.HeapType::new(a_idx)
  let b_heap = @lib.HeapType::new(b_idx)
  let nullable_a_ref = @lib.ValType::ref_type(@lib.RefType::new(true, a_heap))
  let b_ref = @lib.ValType::ref_type(@lib.RefType::new(false, b_heap))
  let a = @lib.RecType::new(
    @lib.SubType::new(
      false,
      [],
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::val_type(nullable_a_ref),
          @lib.Mut::const_(),
        ),
      ]),
    ),
  )
  let b = @lib.RecType::new(
    @lib.SubType::new(
      false,
      [a_idx],
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::val_type(b_ref),
          @lib.Mut::const_(),
        ),
      ]),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([b_ref], [@lib.ValType::anyref()]),
    ),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([a, b, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([nullable_a_ref]),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
          @lib.Instruction::struct_get(a_idx, 0U),
        ]),
      ),
    ]),
  )
}

///|
fn rse_test_array_get_refinalize_module() -> @lib.Module {
  let a_idx = @lib.TypeIdx::new(0U)
  let b_idx = @lib.TypeIdx::new(1U)
  let nullable_a_ref = @lib.ValType::ref_array_nullable(a_idx)
  let b_ref = @lib.ValType::ref_array_nonnull(b_idx)
  let a = @lib.RecType::new(
    @lib.SubType::new(
      false,
      [],
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(nullable_a_ref),
          @lib.Mut::const_(),
        ),
      ),
    ),
  )
  let b = @lib.RecType::new(
    @lib.SubType::new(
      false,
      [a_idx],
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(b_ref),
          @lib.Mut::const_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([b_ref], [@lib.ValType::anyref()]),
    ),
  )
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new([a, b, func_type]))
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(2U)]))
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([nullable_a_ref]),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          @lib.Instruction::local_tee(@lib.LocalIdx::new(1U)),
          @lib.Instruction::i32_const(@lib.I32::new(0)),
          @lib.Instruction::array_get(a_idx),
        ]),
      ),
    ]),
  )
}

///|
test "rse removes body-local default same-value set shells" {
  let optimized = match
    pass_test_run_pipeline(
      "(module (func (local i32) i32.const 0 local.set 0))",
      ["redundant-set-elimination"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected rse default local fixture success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(instrs)) = rse_test_first_defined_func(optimized)
  match instrs {
    [@lib.Instruction::I32Const(_), @lib.Instruction::Drop] => ()
    other =>
      fail(
        "expected default local set shell to become drop, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "rse raw path folds repeated string.const local sets" {
  let optimized = rse_test_run_module(
    @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(@lib.SubType::comp_type(@lib.CompType::func([], []))),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([@lib.ValType::stringref()]),
          @lib.Expr::new([
            @lib.Instruction::string_const(b"rse"),
            @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
            @lib.Instruction::string_const(b"rse"),
            @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
          ]),
        ),
      ]),
    ),
  )
  let @lib.Func(_, @lib.Expr(instrs)) = rse_test_first_defined_func(optimized)
  match instrs {
    [
      @lib.Instruction::StringConst(_),
      @lib.Instruction::LocalSet(_),
      @lib.Instruction::StringConst(_),
      @lib.Instruction::Drop,
    ] => ()
    other =>
      fail(
        "expected repeated string.const set shell to become drop, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "rse retargets equivalent local.get to strict subtype local" {
  let input =
    #|(module
    #|  (func (local anyref eqref)
    #|    ref.null eq
    #|    local.set 1
    #|    local.get 1
    #|    local.set 0
    #|    local.get 0
    #|    drop))
    #|
  let optimized = match
    pass_test_run_pipeline(input, ["redundant-set-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected rse refined get fixture success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(instrs)) = rse_test_first_defined_func(optimized)
  match instrs {
    [
      @lib.Instruction::RefNull(_),
      @lib.Instruction::Drop,
      @lib.Instruction::LocalGet(_),
      @lib.Instruction::LocalSet(_),
      @lib.Instruction::LocalGet(@lib.LocalIdx(raw)),
      @lib.Instruction::Drop,
    ] => @debug.assert_eq(raw, 1U)
    other =>
      fail(
        "expected retargeted local.get lowered shape, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "rse treats ref.as_non_null refined locals as equivalent subtype sources" {
  let input =
    #|(module
    #|  (type $A (sub (struct)))
    #|  (func (param (ref null $A) (ref $A))
    #|    local.get 0
    #|    ref.as_non_null
    #|    local.set 1
    #|    (drop (local.get 0))
    #|    (drop (local.get 1))))
    #|
  let optimized = match
    pass_test_run_pipeline(input, ["redundant-set-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected rse ref.as_non_null refined fixture success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(instrs)) = rse_test_first_defined_func(optimized)
  match instrs {
    [
      @lib.Instruction::LocalGet(@lib.LocalIdx(refined_src)),
      @lib.Instruction::RefAsNonNull,
      @lib.Instruction::LocalSet(_),
      @lib.Instruction::LocalGet(@lib.LocalIdx(retargeted)),
      @lib.Instruction::Drop,
      @lib.Instruction::LocalGet(@lib.LocalIdx(original_refined)),
      @lib.Instruction::Drop,
    ] => {
      @debug.assert_eq(refined_src, 0U)
      @debug.assert_eq(retargeted, 1U)
      @debug.assert_eq(original_refined, 1U)
    }
    other =>
      fail(
        "expected ref.as_non_null refined local.get retargeting, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "rse treats ref.cast refined locals as equivalent subtype sources" {
  let optimized = rse_test_run_module(
    rse_test_refined_cast_module(
      @lib.Instruction::ref_cast(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
    ),
  )
  let @lib.Func(_, @lib.Expr(instrs)) = rse_test_first_defined_func(optimized)
  match instrs {
    [
      @lib.Instruction::LocalGet(@lib.LocalIdx(cast_src)),
      @lib.Instruction::RefCast(_, _),
      @lib.Instruction::LocalSet(_),
      @lib.Instruction::LocalGet(@lib.LocalIdx(retargeted)),
      @lib.Instruction::Drop,
      @lib.Instruction::LocalGet(@lib.LocalIdx(original_refined)),
      @lib.Instruction::Drop,
    ] => {
      @debug.assert_eq(cast_src, 0U)
      @debug.assert_eq(retargeted, 1U)
      @debug.assert_eq(original_refined, 1U)
    }
    other =>
      fail(
        "expected ref.cast refined local.get retargeting, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "rse treats ref.cast_desc_eq refined locals as equivalent subtype sources" {
  let optimized = rse_test_run_module(
    rse_test_refined_cast_module(
      @lib.Instruction::ref_cast_desc_eq(
        false,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      ),
    ),
  )
  let @lib.Func(_, @lib.Expr(instrs)) = rse_test_first_defined_func(optimized)
  match instrs {
    [
      @lib.Instruction::LocalGet(@lib.LocalIdx(cast_src)),
      @lib.Instruction::RefCastDescEq(_, _),
      @lib.Instruction::LocalSet(_),
      @lib.Instruction::LocalGet(@lib.LocalIdx(retargeted)),
      @lib.Instruction::Drop,
      @lib.Instruction::LocalGet(@lib.LocalIdx(original_refined)),
      @lib.Instruction::Drop,
    ] => {
      @debug.assert_eq(cast_src, 0U)
      @debug.assert_eq(retargeted, 1U)
      @debug.assert_eq(original_refined, 1U)
    }
    other =>
      fail(
        "expected ref.cast_desc_eq refined local.get retargeting, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "rse retargets struct.get after redundant tee removal for refinalized field type" {
  let optimized = rse_test_run_module(rse_test_needs_refinalize_module())
  let @lib.Func(_, @lib.Expr(instrs)) = rse_test_first_defined_func(optimized)
  match instrs {
    [
      @lib.Instruction::LocalGet(@lib.LocalIdx(first_get)),
      @lib.Instruction::LocalSet(_),
      @lib.Instruction::LocalGet(@lib.LocalIdx(second_get)),
      @lib.Instruction::StructGet(@lib.TypeIdx(struct_type), @lib.U32(0U)),
    ] => {
      @debug.assert_eq(first_get, 0U)
      @debug.assert_eq(second_get, 0U)
      @debug.assert_eq(struct_type, 1U)
    }
    other =>
      fail(
        "expected redundant tee to be removed and struct.get retargeted to subtype, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "rse retargets array.get after redundant tee removal for refinalized element type" {
  let optimized = rse_test_run_module(rse_test_array_get_refinalize_module())
  let @lib.Func(_, @lib.Expr(instrs)) = rse_test_first_defined_func(optimized)
  match instrs {
    [
      @lib.Instruction::LocalGet(@lib.LocalIdx(first_get)),
      @lib.Instruction::LocalSet(_),
      @lib.Instruction::LocalGet(@lib.LocalIdx(second_get)),
      @lib.Instruction::I32Const(_),
      @lib.Instruction::ArrayGet(@lib.TypeIdx(array_type)),
    ] => {
      @debug.assert_eq(first_get, 0U)
      @debug.assert_eq(second_get, 0U)
      @debug.assert_eq(array_type, 1U)
    }
    other =>
      fail(
        "expected redundant tee to be removed and array.get retargeted to subtype, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "rse keeps unrefined local.gets when the candidate is not a strict subtype" {
  let input =
    #|(module
    #|  (type $A (sub (struct)))
    #|  (func (param (ref $A) (ref null $A))
    #|    local.get 0
    #|    local.set 1
    #|    (drop (local.get 1))
    #|    (drop (local.get 0))))
    #|
  let optimized = match
    pass_test_run_pipeline(input, ["redundant-set-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected rse strict-subtype negative fixture success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(instrs)) = rse_test_first_defined_func(optimized)
  match instrs {
    [
      @lib.Instruction::LocalGet(@lib.LocalIdx(copy_src)),
      @lib.Instruction::LocalSet(_),
      @lib.Instruction::LocalGet(@lib.LocalIdx(retargeted)),
      @lib.Instruction::Drop,
      @lib.Instruction::LocalGet(@lib.LocalIdx(preserved)),
      @lib.Instruction::Drop,
    ] => {
      @debug.assert_eq(copy_src, 0U)
      @debug.assert_eq(retargeted, 0U)
      @debug.assert_eq(preserved, 0U)
    }
    other =>
      fail(
        "expected only the nullable read to retarget, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "rse preserves refined local.get retargeting through branch merges" {
  let input =
    #|(module
    #|  (type $A (sub (struct)))
    #|  (func (param i32 (ref null $A) (ref $A))
    #|    local.get 1
    #|    ref.as_non_null
    #|    local.set 2
    #|    (if (local.get 0)
    #|      (then
    #|        (drop (local.get 1)))
    #|      (else
    #|        (drop (local.get 2))))
    #|    (drop (local.get 1))))
    #|
  let optimized = match
    pass_test_run_pipeline(input, ["redundant-set-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected rse branch refined-get fixture success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(instrs)) = rse_test_first_defined_func(optimized)
  match instrs {
    [
      @lib.Instruction::LocalGet(@lib.LocalIdx(refined_src)),
      @lib.Instruction::RefAsNonNull,
      @lib.Instruction::LocalSet(_),
      @lib.Instruction::LocalGet(_),
      @lib.Instruction::If(_, then_body, Some(else_body)),
      @lib.Instruction::LocalGet(@lib.LocalIdx(final_idx)),
      @lib.Instruction::Drop,
    ] => {
      @debug.assert_eq(refined_src, 1U)
      @debug.assert_eq(final_idx, 2U)
      match then_body {
        [
          @lib.Instruction::LocalGet(@lib.LocalIdx(then_idx)),
          @lib.Instruction::Drop,
        ] => @debug.assert_eq(then_idx, 2U)
        other =>
          fail(
            "expected then arm to retarget to the refined local, got \{@debug.to_string(other)}",
          )
      }
      match else_body {
        [
          @lib.Instruction::LocalGet(@lib.LocalIdx(else_idx)),
          @lib.Instruction::Drop,
        ] => @debug.assert_eq(else_idx, 2U)
        other =>
          fail(
            "expected else arm to keep the refined local, got \{@debug.to_string(other)}",
          )
      }
    }
    other =>
      fail(
        "expected branch merge refined local.get retargeting, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "rse removes default local tee in loop conditions" {
  let input =
    #|(module
    #|  (func (param i32) (local i32)
    #|    (if (local.get 0) (then unreachable))
    #|    (loop
    #|      (if
    #|        (i32.lt_u
    #|          (local.tee 1 (i32.const 0))
    #|          (i32.const 1)
    #|        )
    #|        (then br 0)
    #|      )
    #|    )
    #|  )
    #|)
  let optimized = match
    pass_test_run_pipeline(input, ["redundant-set-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected rse loop default tee fixture success, got \{err}")
  }
  let pretty = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.tee"), msg=pretty)
}

///|
test "rse hot path folds post-block set when body falls through with same value" {
  let func = rse_test_run_hot(
    "(module (func (local i32) block i32.const 1 local.set 0 end i32.const 1 local.set 0))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  rse_expect_op(func, @ir.hot_root_get(func, 1), "drop")
}

///|
test "rse hot path folds post-block set when branch exit agrees with fallthrough" {
  let func = rse_test_run_hot(
    "(module (func (param i32) (local i32) block i32.const 1 local.set 1 local.get 0 br_if 0 end i32.const 1 local.set 1))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  rse_expect_op(func, @ir.hot_root_get(func, 1), "drop")
}

///|
test "rse hot path folds post-block set when br_table exit agrees" {
  let func = rse_test_run_hot(
    "(module (func (param i32) (local i32) block i32.const 1 local.set 1 local.get 0 br_table 0 0 end i32.const 1 local.set 1))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  rse_expect_op(func, @ir.hot_root_get(func, 1), "drop")
}

///|
test "rse hot path keeps block-exit disagreement final const set" {
  let func = rse_test_run_hot(
    "(module (func (param i32) (local i32) block local.get 0 br_if 0 i32.const 1 local.set 1 end i32.const 1 local.set 1))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  rse_expect_op(func, @ir.hot_root_get(func, 1), "local.set")
}

///|
test "rse hot path keeps if-exit disagreement final const set" {
  let func = rse_test_run_hot(
    "(module (func (param i32) (local i32) local.get 0 if br 0 else i32.const 1 local.set 1 end i32.const 1 local.set 1))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  rse_expect_op(func, @ir.hot_root_get(func, 1), "local.set")
}

///|
test "rse hot path folds post-if set when branch exit agrees with else" {
  let func = rse_test_run_hot(
    "(module (func (param i32) (local i32) local.get 0 if i32.const 1 local.set 1 br 0 else i32.const 1 local.set 1 end i32.const 1 local.set 1))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  rse_expect_op(func, @ir.hot_root_get(func, 1), "drop")
}

///|
test "rse raw path preserves branch disagreement as a merge value for self sets" {
  let input =
    #|(module
    #|  (func (param i32) (local i32)
    #|    local.get 0
    #|    if
    #|      i32.const 1
    #|      local.set 1
    #|    else
    #|      i32.const 2
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    local.set 1))
    #|
  let optimized = match
    pass_test_run_pipeline(input, ["redundant-set-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected rse branch merge fixture success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(instrs)) = rse_test_first_defined_func(optimized)
  match instrs {
    [
      @lib.Instruction::LocalGet(_),
      @lib.Instruction::If(_, _, _),
      @lib.Instruction::LocalGet(_),
      @lib.Instruction::Drop,
    ] => ()
    other =>
      fail(
        "expected self-set shell to become drop after branch merge, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "rse raw path keeps br_on_null block-exit disagreement final const set" {
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::anyref()], [])),
  )
  let optimized = rse_test_run_module(
    @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::single(1U, @lib.ValType::i32()),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(@lib.I32::new(1)),
                @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
              ]),
            ),
            @lib.Instruction::i32_const(@lib.I32::new(1)),
            @lib.Instruction::local_set(@lib.LocalIdx::new(1U)),
          ]),
        ),
      ]),
    ),
  )
  let @lib.Func(_, @lib.Expr(instrs)) = rse_test_first_defined_func(optimized)
  match instrs {
    [
      @lib.Instruction::Block(_, _),
      @lib.Instruction::I32Const(_),
      @lib.Instruction::LocalSet(_),
    ] => ()
    other =>
      fail(
        "expected final const set to survive br_on_null block-exit disagreement, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "rse raw path folds post-loop set after branch-free loop fallthrough" {
  let input =
    #|(module
    #|  (func (local i32)
    #|    loop
    #|      i32.const 1
    #|      local.set 0
    #|    end
    #|    i32.const 1
    #|    local.set 0))
    #|
  let optimized = match
    pass_test_run_pipeline(input, ["redundant-set-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected rse branch-free loop fixture success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(instrs)) = rse_test_first_defined_func(optimized)
  match instrs {
    [
      @lib.Instruction::Loop(_, _),
      @lib.Instruction::I32Const(_),
      @lib.Instruction::Drop,
    ] => ()
    other =>
      fail(
        "expected post-loop same-value set to become drop, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "rse hot path folds post-loop set after branch-free loop fallthrough" {
  let func = rse_test_run_hot(
    "(module (func (local i32) loop i32.const 1 local.set 0 end i32.const 1 local.set 0))",
  )

  @debug.assert_eq(@ir.hot_root_count(func), 2)
  rse_expect_op(func, @ir.hot_root_get(func, 1), "drop")
}

///|
test "rse raw path keeps post-loop set after loop backedge" {
  let input =
    #|(module
    #|  (func (param i32) (local i32)
    #|    loop
    #|      local.get 0
    #|      br_if 0
    #|      i32.const 1
    #|      local.set 1
    #|    end
    #|    i32.const 1
    #|    local.set 1))
    #|
  let optimized = match
    pass_test_run_pipeline(input, ["redundant-set-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected rse loop-backedge fixture success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(instrs)) = rse_test_first_defined_func(optimized)
  match instrs {
    [
      @lib.Instruction::Loop(_, _),
      @lib.Instruction::I32Const(_),
      @lib.Instruction::LocalSet(_),
    ] => ()
    other =>
      fail(
        "expected post-loop const set to survive loop backedge, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "rse raw path keeps post-loop set after outer loop exit" {
  let input =
    #|(module
    #|  (func (param i32) (local i32)
    #|    block
    #|      loop
    #|        local.get 0
    #|        br_if 1
    #|        i32.const 1
    #|        local.set 1
    #|      end
    #|    end
    #|    i32.const 1
    #|    local.set 1))
    #|
  let optimized = match
    pass_test_run_pipeline(input, ["redundant-set-elimination"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected rse loop-exit fixture success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(instrs)) = rse_test_first_defined_func(optimized)
  match instrs {
    [
      @lib.Instruction::Block(_, _),
      @lib.Instruction::I32Const(_),
      @lib.Instruction::LocalSet(_),
    ] => ()
    other =>
      fail(
        "expected post-loop const set to survive outer loop-exit disagreement, got \{@debug.to_string(other)}",
      )
  }
}

///|
test "rse raw path keeps block-exit disagreement final const set" {
  let input =
    #|(module
    #|  (func (param i32) (local i32)
    #|    block
    #|      local.get 0
    #|      br_if 0
    #|      i32.const 1
    #|      local.set 1
    #|    end
    #|    i32.const 1
    #|    local.set 1))
    #|
  let optimized = match
    pass_test_run_pipeline(input, ["redundant-set-elimination"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected rse block-exit merge fixture success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(instrs)) = rse_test_first_defined_func(optimized)
  match instrs {
    [
      @lib.Instruction::Block(_, _),
      @lib.Instruction::I32Const(_),
      @lib.Instruction::LocalSet(_),
    ] => ()
    other =>
      fail(
        "expected final const set to survive block-exit disagreement, got \{@debug.to_string(other)}",
      )
  }
}
