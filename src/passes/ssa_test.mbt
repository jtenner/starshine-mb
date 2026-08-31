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
fn ssa_full_test_collect_local_set_indices(
  instrs : Array[@lib.Instruction],
  out : Array[UInt],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.LocalSet(@lib.LocalIdx(idx)) => out.push(idx)
      @lib.If(_, then_body, else_body) => {
        ssa_full_test_collect_local_set_indices(then_body, out)
        match else_body {
          Some(else_body) =>
            ssa_full_test_collect_local_set_indices(else_body, out)
          None => ()
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        ssa_full_test_collect_local_set_indices(body, out)
      _ => ()
    }
  }
}

///|
fn ssa_full_test_local_set_indices(
  instrs : Array[@lib.Instruction],
) -> Array[UInt] {
  let out : Array[UInt] = []
  ssa_full_test_collect_local_set_indices(instrs, out)
  out
}

///|
fn ssa_full_test_collect_local_tee_indices(
  instrs : Array[@lib.Instruction],
  out : Array[UInt],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.LocalTee(@lib.LocalIdx(idx)) => out.push(idx)
      @lib.If(_, then_body, else_body) => {
        ssa_full_test_collect_local_tee_indices(then_body, out)
        match else_body {
          Some(else_body) =>
            ssa_full_test_collect_local_tee_indices(else_body, out)
          None => ()
        }
      }
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        ssa_full_test_collect_local_tee_indices(body, out)
      _ => ()
    }
  }
}

///|
fn ssa_full_test_local_tee_indices(
  instrs : Array[@lib.Instruction],
) -> Array[UInt] {
  let out : Array[UInt] = []
  ssa_full_test_collect_local_tee_indices(instrs, out)
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
  @debug.assert_eq(rewrite.merge_local, 4)
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
  @debug.assert_eq(rewrite.merge_local, 3)
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
  @debug.assert_eq(rewrite.merge_local, 3)
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
test "full ssa public pass preserves reads from an already-ssa body-local write" {
  let source =
    #|(module
    #|  (func (result i32)
    #|    (local i32)
    #|    i32.const 15
    #|    local.set 0
    #|    local.get 0))
  let optimized = match pass_test_run_pipeline(source, ["ssa"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected already-ssa local success, got \{err}")
  }
  let (_, instrs) = try! ssa_full_test_first_defined_func(optimized)
  assert_true(
    ssa_full_test_local_get_indices(instrs).contains(0U),
    msg=instrs.to_string(),
  )
}

///|
test "full ssa public pass materializes simple explicit-write merge locals" {
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
    Err(err) => fail("expected simple explicit-write merge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_full_test_first_defined_func(optimized)
  @debug.assert_eq(locals.length(), 4)
  @debug.assert_eq(ssa_full_test_local_set_indices(instrs), [2U, 3U])
  @debug.assert_eq(ssa_full_test_local_tee_indices(instrs), [4U, 4U])
  assert_true(
    ssa_full_test_local_get_indices(instrs).any(fn(idx) { idx == 4U }),
    msg=instrs.to_string(),
  )
  assert_false(
    ssa_full_test_local_get_indices(instrs).any(fn(idx) { idx == 1U }),
    msg=instrs.to_string(),
  )
}

///|
test "full ssa public pass prepends parameter-entry merge values" {
  let source =
    #|(module
    #|  (func (param i32 i32) (result i32)
    #|    local.get 0
    #|    if
    #|      i32.const 7
    #|      local.set 1
    #|    else
    #|      nop
    #|    end
    #|    local.get 1))
  let optimized = match pass_test_run_pipeline(source, ["ssa"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected parameter-entry merge fail-closed success, got \{err}")
  }

  let (locals, instrs) = try! ssa_full_test_first_defined_func(optimized)
  @debug.assert_eq(locals.length(), 2)
  let sets = ssa_full_test_local_set_indices(instrs)
  assert_true(sets.contains(2U), msg=instrs.to_string())
  assert_true(sets.contains(3U), msg=instrs.to_string())
  @debug.assert_eq(ssa_full_test_local_tee_indices(instrs), [3U])
  assert_true(
    ssa_full_test_local_get_indices(instrs).any(fn(idx) { idx == 3U }),
    msg=instrs.to_string(),
  )
}

///|
test "full ssa public pass uses fresh-local defaults for one-arm body merges" {
  let source =
    #|(module
    #|  (func (param i32) (result i32)
    #|    (local i32)
    #|    local.get 0
    #|    if
    #|      i32.const 7
    #|      local.set 1
    #|    end
    #|    local.get 1))
  let optimized = match pass_test_run_pipeline(source, ["ssa"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected default-entry merge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_full_test_first_defined_func(optimized)
  @debug.assert_eq(locals.length(), 3)
  @debug.assert_eq(ssa_full_test_local_set_indices(instrs), [2U])
  @debug.assert_eq(ssa_full_test_local_tee_indices(instrs), [3U])
  assert_true(
    ssa_full_test_local_get_indices(instrs).any(fn(idx) { idx == 3U }),
    msg=instrs.to_string(),
  )
}

///|
test "full ssa public pass nests merge tees when two gets share predecessor sets" {
  let source =
    #|(module
    #|  (func (param i32)
    #|    (local i32)
    #|    local.get 0
    #|    if
    #|      i32.const 7
    #|      local.set 1
    #|    else
    #|      i32.const 9
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    drop
    #|    local.get 1
    #|    drop))
  let optimized = match pass_test_run_pipeline(source, ["ssa"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected shared-set merge success, got \{err}")
  }

  let (locals, instrs) = try! ssa_full_test_first_defined_func(optimized)
  @debug.assert_eq(locals.length(), 5)
  @debug.assert_eq(ssa_full_test_local_set_indices(instrs), [2U, 3U])
  let tees = ssa_full_test_local_tee_indices(instrs)
  @debug.assert_eq(tees.length(), 4)
  assert_true(tees.contains(4U), msg=instrs.to_string())
  assert_true(tees.contains(5U), msg=instrs.to_string())
  let gets = ssa_full_test_local_get_indices(instrs)
  assert_true(gets.contains(4U), msg=instrs.to_string())
  assert_true(gets.contains(5U), msg=instrs.to_string())
}

///|
test "full ssa public pass handles loop backedge merge locals" {
  let source =
    #|(module
    #|  (func (param i32) (result i32)
    #|    (local i32)
    #|    i32.const 0
    #|    local.set 1
    #|    block
    #|      loop
    #|        local.get 1
    #|        drop
    #|        i32.const 1
    #|        local.set 1
    #|        local.get 0
    #|        br_if 0
    #|      end
    #|    end
    #|    local.get 1))
  let optimized = match pass_test_run_pipeline(source, ["ssa"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected loop full ssa success, got \{err}")
  }
  let (locals, instrs) = try! ssa_full_test_first_defined_func(optimized)
  assert_true(locals.length() >= 4, msg=locals.to_string())
  assert_true(ssa_full_test_local_tee_indices(instrs).length() >= 2)
}

///|
test "full ssa public pass handles branch-target and br_table merges" {
  let source =
    #|(module
    #|  (func (param i32)
    #|    (local i32)
    #|    i32.const 0
    #|    local.set 1
    #|    block
    #|      local.get 0
    #|      br_if 0
    #|      i32.const 7
    #|      local.set 1
    #|    end
    #|    block
    #|      local.get 0
    #|      br_table 0 0
    #|    end
    #|    local.get 1
    #|    drop))
  let optimized = match pass_test_run_pipeline(source, ["ssa"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected branch full ssa success, got \{err}")
  }
  let (locals, instrs) = try! ssa_full_test_first_defined_func(optimized)
  assert_true(locals.length() >= 4, msg=locals.to_string())
  assert_true(ssa_full_test_local_tee_indices(instrs).length() >= 2)
}

///|
test "full ssa public pass handles typed loop local flow" {
  let source =
    #|(module
    #|  (type $loop (func (param i32)))
    #|  (func (param i32)
    #|    (local i32)
    #|    i32.const 0
    #|    local.set 1
    #|    local.get 0
    #|    loop (type $loop)
    #|      drop
    #|      local.get 1
    #|      drop
    #|      i32.const 1
    #|      local.set 1
    #|      local.get 0
    #|      br 0
    #|    end
    #|    local.get 1
    #|    drop))
  let optimized = match pass_test_run_pipeline(source, ["ssa"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected typed-control full ssa success, got \{err}")
  }
  let (locals, instrs) = try! ssa_full_test_first_defined_func(optimized)
  assert_true(locals.length() >= 4, msg=locals.to_string())
  assert_true(ssa_full_test_local_tee_indices(instrs).length() >= 2)
}

///|
test "full ssa public pass handles explicit exceptional predecessors" {
  let source =
    #|(module
    #|  (tag $e)
    #|  (func (param i32)
    #|    (local i32)
    #|    block
    #|      try_table (catch_all 0)
    #|        i32.const 7
    #|        local.set 1
    #|        throw $e
    #|      end
    #|      i32.const 9
    #|      local.set 1
    #|    end
    #|    local.get 1
    #|    drop))
  let optimized = match pass_test_run_pipeline(source, ["ssa"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected EH full ssa success, got \{err}")
  }
  let (locals, instrs) = try! ssa_full_test_first_defined_func(optimized)
  assert_true(locals.length() >= 4, msg=locals.to_string())
  assert_true(ssa_full_test_local_tee_indices(instrs).length() >= 2)
}
