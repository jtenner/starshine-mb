///|
fn ssa_full_test_first_defined_func(
  mod_ : @lib.Module,
) -> (@lib.Locals, Array[@lib.Instruction]) raise {
  match mod_.code_sec {
    Some(@lib.CodeSec([@lib.Func(locals, @lib.Expr(instrs))])) =>
      (locals, instrs)
    Some(@lib.CodeSec(_)) => fail("expected exactly one defined function")
    None => fail("expected code section")
  }
}

///|
fn ssa_full_test_collect_local_get_indices(
  instrs : Array[@lib.Instruction],
  out : Array[UInt],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.LocalGet(@lib.LocalIdx(idx)) => out.push(idx)
      @lib.If(_, then_body, else_body) => {
        ssa_full_test_collect_local_get_indices(then_body, out)
        match else_body {
          Some(else_body) =>
            ssa_full_test_collect_local_get_indices(else_body, out)
          None => ()
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        ssa_full_test_collect_local_get_indices(body, out)
      _ => ()
    }
  }
}

///|
fn ssa_full_test_local_get_indices(
  instrs : Array[@lib.Instruction],
) -> Array[UInt] {
  let out : Array[UInt] = []
  ssa_full_test_collect_local_get_indices(instrs, out)
  out
}

///|
fn ssa_full_test_instrs_have_ref_null_type(
  instrs : Array[@lib.Instruction],
  expected : @lib.RefType,
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.RefNull(rt) => if rt == expected { return true }
      @lib.If(_, then_body, else_body) => {
        if ssa_full_test_instrs_have_ref_null_type(then_body, expected) {
          return true
        }
        match else_body {
          Some(else_body) =>
            if ssa_full_test_instrs_have_ref_null_type(else_body, expected) {
              return true
            }
          None => ()
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if ssa_full_test_instrs_have_ref_null_type(body, expected) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn ssa_full_test_merge_plan(func : @ir.HotFunc) -> SsaFullRewritePlan {
  let graph = @ir.local_graph_build(func, @ir.cfg_build(func))
  ssa_full_build_merge_rewrite_plan(func, graph)
}

///|
fn ssa_full_test_plan_has_input(
  inputs : Array[SsaFullMergeInput],
  expected : SsaFullMergeInput,
) -> Bool {
  for input in inputs {
    if input == expected {
      return true
    }
  }
  false
}

///|
test "full ssa planner creates merge action for explicit diamond writes" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let then_set = @ir.hot_build_local_set(
    func,
    1,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  )
  let else_set = @ir.hot_build_local_set(
    func,
    1,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [then_set],
    else_body=Some([else_set]),
  )
  let merge_get = @ir.hot_build_local_get(func, 1)
  @ir.hot_root_append(func, if_id)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, merge_get))

  let plan = ssa_full_test_merge_plan(func)

  @debug.assert_eq(plan.merge_gets.length(), 1)
  let rewrite = plan.merge_gets[0]
  @debug.assert_eq(rewrite.get_id, merge_get)
  @debug.assert_eq(rewrite.original_local, 1)
  @debug.assert_eq(rewrite.merge_local, 2)
  @debug.assert_eq(rewrite.inputs.length(), 2)
  assert_true(
    ssa_full_test_plan_has_input(
      rewrite.inputs,
      SsaFullMergeInput::ExplicitWrite(then_set),
    ),
  )
  assert_true(
    ssa_full_test_plan_has_input(
      rewrite.inputs,
      SsaFullMergeInput::ExplicitWrite(else_set),
    ),
  )
}

///|
test "full ssa planner models parameter-entry merge prepends" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let then_set = @ir.hot_build_local_set(
    func,
    1,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [then_set],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  let merge_get = @ir.hot_build_local_get(func, 1)
  @ir.hot_root_append(func, if_id)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, merge_get))

  let plan = ssa_full_test_merge_plan(func)

  @debug.assert_eq(plan.merge_gets.length(), 1)
  let rewrite = plan.merge_gets[0]
  @debug.assert_eq(rewrite.get_id, merge_get)
  @debug.assert_eq(rewrite.merge_local, 2)
  assert_true(
    ssa_full_test_plan_has_input(
      rewrite.inputs,
      SsaFullMergeInput::ExplicitWrite(then_set),
    ),
  )
  assert_true(
    ssa_full_test_plan_has_input(
      rewrite.inputs,
      SsaFullMergeInput::ParamEntry(1),
    ),
  )
}

///|
test "full ssa planner models default-entry merges without prepends" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let then_set = @ir.hot_build_local_set(
    func,
    1,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [then_set],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  let merge_get = @ir.hot_build_local_get(func, 1)
  @ir.hot_root_append(func, if_id)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, merge_get))

  let plan = ssa_full_test_merge_plan(func)

  @debug.assert_eq(plan.merge_gets.length(), 1)
  let rewrite = plan.merge_gets[0]
  @debug.assert_eq(rewrite.get_id, merge_get)
  @debug.assert_eq(rewrite.merge_local, 2)
  assert_true(
    ssa_full_test_plan_has_input(
      rewrite.inputs,
      SsaFullMergeInput::ExplicitWrite(then_set),
    ),
  )
  assert_true(
    ssa_full_test_plan_has_input(
      rewrite.inputs,
      SsaFullMergeInput::DefaultEntry(1),
    ),
  )
  assert_false(
    ssa_full_test_plan_has_input(
      rewrite.inputs,
      SsaFullMergeInput::ParamEntry(1),
    ),
  )
}

///|
test "full ssa planner skips nondefaultable default-entry merges" {
  let heap = @lib.HeapType::new(@lib.TypeIdx::new(0U))
  let nonnull_ref = @lib.ValType::ref_type(@lib.RefType::new(false, heap))
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32(), nonnull_ref], locals=[
      nonnull_ref,
    ]),
  )
  let then_set = @ir.hot_build_local_set(
    func,
    2,
    @ir.hot_build_local_get(func, 1),
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [then_set],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  let merge_get = @ir.hot_build_local_get(func, 2)
  @ir.hot_root_append(func, if_id)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, merge_get))

  let plan = ssa_full_test_merge_plan(func)

  @debug.assert_eq(plan.merge_gets.length(), 0)
}

///|
test "full ssa planner ignores single-source gets for no-merge sibling contrast" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let set = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  )
  let get = @ir.hot_build_local_get(func, 0)
  @ir.hot_root_append(func, set)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, get))

  let plan = ssa_full_test_merge_plan(func)

  @debug.assert_eq(plan.merge_gets.length(), 0)
}

///|
test "full ssa public pass freshens repeated parameter overwrites" {
  let source =
    #|(module
    #|  (func (param i32) (result i32)
    #|    local.get 0
    #|    i32.const 1
    #|    i32.add
    #|    local.set 0
    #|    local.get 0
    #|    i32.const 2
    #|    i32.add
    #|    local.set 0
    #|    local.get 0))
  let optimized = match pass_test_run_pipeline(source, ["ssa"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected active full ssa non-merge rewrite success, got \{err}")
  }

  let (locals, instrs) = try! ssa_full_test_first_defined_func(optimized)
  let gets = ssa_full_test_local_get_indices(instrs)
  assert_true(locals.length() >= 2, msg=locals.to_string())
  assert_true(gets.any(fn(idx) { idx == 1U }), msg=instrs.to_string())
  assert_true(gets.any(fn(idx) { idx == 2U }), msg=instrs.to_string())
}

///|
test "full ssa public pass replaces default exact ref reads" {
  let source =
    #|(module
    #|  (type $box (sub (struct (field i32))))
    #|  (func (result i32)
    #|    (local (ref null (exact $box)))
    #|    local.get 0
    #|    ref.as_non_null
    #|    struct.get $box 0))
  let optimized = match pass_test_run_pipeline(source, ["ssa"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected active full ssa default-ref rewrite success, got \{err}")
  }

  let (_, instrs) = try! ssa_full_test_first_defined_func(optimized)
  assert_false(
    instrs.to_string().contains("local.get"),
    msg="default-ref replacement should remove the body-local read: \{instrs}",
  )
  assert_true(
    ssa_full_test_instrs_have_ref_null_type(
      instrs,
      @lib.RefType::new(
        true,
        @lib.HeapType::new(@lib.TypeIdx::new(0U)),
        exact=true,
      ),
    ),
    msg=instrs.to_string(),
  )
}

///|
test "full ssa public pass leaves merge families fail-closed until merge materialization" {
  let source =
    #|(module
    #|  (func (param i32) (result i32)
    #|    (local i32)
    #|    local.get 0
    #|    if
    #|      i32.const 7
    #|      local.set 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|    end
    #|    local.get 1))
  let optimized = match pass_test_run_pipeline(source, ["ssa"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected merge-family fail-closed success, got \{err}")
  }

  let (locals, instrs) = try! ssa_full_test_first_defined_func(optimized)
  @debug.assert_eq(locals.length(), 1)
  assert_true(
    ssa_full_test_local_get_indices(instrs).any(fn(idx) { idx == 1U }),
    msg=instrs.to_string(),
  )
}
