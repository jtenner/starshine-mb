///|
fn lcse_test_defined_func(mod_ : @lib.Module, idx : Int) -> @lib.Func {
  match mod_.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      match funcs.get(idx) {
        Some(func) => func
        None => abort("expected defined function")
      }
    None => abort("expected code section")
  }
}

///|
fn lcse_test_first_defined_func(mod_ : @lib.Module) -> @lib.Func {
  lcse_test_defined_func(mod_, 0)
}

///|
fn lcse_test_count_local_tee(
  instrs : Array[@lib.Instruction],
  local_idx : @lib.LocalIdx,
) -> Int {
  let mut count = 0
  for instr in instrs {
    match instr {
      @lib.Instruction::LocalTee(idx) => if idx == local_idx { count += 1 }
      @lib.Instruction::Block(_, @lib.Expr(body))
      | @lib.Instruction::Loop(_, @lib.Expr(body)) =>
        count += lcse_test_count_local_tee(body, local_idx)
      @lib.Instruction::If(_, then_body, Some(else_body)) => {
        count += lcse_test_count_local_tee(then_body, local_idx)
        count += lcse_test_count_local_tee(else_body, local_idx)
      }
      @lib.Instruction::If(_, then_body, None) =>
        count += lcse_test_count_local_tee(then_body, local_idx)
      @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
        count += lcse_test_count_local_tee(body, local_idx)
      _ => ()
    }
  }
  count
}

///|
fn lcse_test_count_any_local_tee(instrs : Array[@lib.Instruction]) -> Int {
  let mut count = 0
  for instr in instrs {
    match instr {
      @lib.Instruction::LocalTee(_) => count += 1
      @lib.Instruction::Block(_, @lib.Expr(body))
      | @lib.Instruction::Loop(_, @lib.Expr(body)) =>
        count += lcse_test_count_any_local_tee(body)
      @lib.Instruction::If(_, then_body, Some(else_body)) => {
        count += lcse_test_count_any_local_tee(then_body)
        count += lcse_test_count_any_local_tee(else_body)
      }
      @lib.Instruction::If(_, then_body, None) =>
        count += lcse_test_count_any_local_tee(then_body)
      @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
        count += lcse_test_count_any_local_tee(body)
      _ => ()
    }
  }
  count
}

///|
fn lcse_test_count_drop(instrs : Array[@lib.Instruction]) -> Int {
  let mut count = 0
  for instr in instrs {
    match instr {
      @lib.Instruction::Drop => count += 1
      @lib.Instruction::Block(_, @lib.Expr(body))
      | @lib.Instruction::Loop(_, @lib.Expr(body)) =>
        count += lcse_test_count_drop(body)
      @lib.Instruction::If(_, then_body, Some(else_body)) => {
        count += lcse_test_count_drop(then_body)
        count += lcse_test_count_drop(else_body)
      }
      @lib.Instruction::If(_, then_body, None) =>
        count += lcse_test_count_drop(then_body)
      @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
        count += lcse_test_count_drop(body)
      _ => ()
    }
  }
  count
}

///|
fn lcse_test_count_ref_as_non_null(instrs : Array[@lib.Instruction]) -> Int {
  let mut count = 0
  for instr in instrs {
    match instr {
      @lib.Instruction::RefAsNonNull => count += 1
      @lib.Instruction::Block(_, @lib.Expr(body))
      | @lib.Instruction::Loop(_, @lib.Expr(body)) =>
        count += lcse_test_count_ref_as_non_null(body)
      @lib.Instruction::If(_, then_body, Some(else_body)) => {
        count += lcse_test_count_ref_as_non_null(then_body)
        count += lcse_test_count_ref_as_non_null(else_body)
      }
      @lib.Instruction::If(_, then_body, None) =>
        count += lcse_test_count_ref_as_non_null(then_body)
      @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
        count += lcse_test_count_ref_as_non_null(body)
      _ => ()
    }
  }
  count
}

///|
fn lcse_test_count_ref_i31(instrs : Array[@lib.Instruction]) -> Int {
  let mut count = 0
  for instr in instrs {
    match instr {
      @lib.Instruction::RefI31 => count += 1
      @lib.Instruction::Block(_, @lib.Expr(body))
      | @lib.Instruction::Loop(_, @lib.Expr(body)) =>
        count += lcse_test_count_ref_i31(body)
      @lib.Instruction::If(_, then_body, Some(else_body)) => {
        count += lcse_test_count_ref_i31(then_body)
        count += lcse_test_count_ref_i31(else_body)
      }
      @lib.Instruction::If(_, then_body, None) =>
        count += lcse_test_count_ref_i31(then_body)
      @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
        count += lcse_test_count_ref_i31(body)
      _ => ()
    }
  }
  count
}

///|
fn lcse_test_count_unreachable(instrs : Array[@lib.Instruction]) -> Int {
  let mut count = 0
  for instr in instrs {
    match instr {
      @lib.Instruction::Unreachable => count += 1
      @lib.Instruction::Block(_, @lib.Expr(body))
      | @lib.Instruction::Loop(_, @lib.Expr(body)) =>
        count += lcse_test_count_unreachable(body)
      @lib.Instruction::If(_, then_body, Some(else_body)) => {
        count += lcse_test_count_unreachable(then_body)
        count += lcse_test_count_unreachable(else_body)
      }
      @lib.Instruction::If(_, then_body, None) =>
        count += lcse_test_count_unreachable(then_body)
      @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
        count += lcse_test_count_unreachable(body)
      _ => ()
    }
  }
  count
}

///|
fn lcse_test_count_block(instrs : Array[@lib.Instruction]) -> Int {
  let mut count = 0
  for instr in instrs {
    match instr {
      @lib.Instruction::Block(_, @lib.Expr(body)) => {
        count += 1
        count += lcse_test_count_block(body)
      }
      @lib.Instruction::Loop(_, @lib.Expr(body)) =>
        count += lcse_test_count_block(body)
      @lib.Instruction::If(_, then_body, Some(else_body)) => {
        count += lcse_test_count_block(then_body)
        count += lcse_test_count_block(else_body)
      }
      @lib.Instruction::If(_, then_body, None) =>
        count += lcse_test_count_block(then_body)
      @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
        count += lcse_test_count_block(body)
      _ => ()
    }
  }
  count
}

///|
fn lcse_test_count_local_get(
  instrs : Array[@lib.Instruction],
  local_idx : @lib.LocalIdx,
) -> Int {
  let mut count = 0
  for instr in instrs {
    match instr {
      @lib.Instruction::LocalGet(idx) => if idx == local_idx { count += 1 }
      @lib.Instruction::Block(_, @lib.Expr(body))
      | @lib.Instruction::Loop(_, @lib.Expr(body)) =>
        count += lcse_test_count_local_get(body, local_idx)
      @lib.Instruction::If(_, then_body, Some(else_body)) => {
        count += lcse_test_count_local_get(then_body, local_idx)
        count += lcse_test_count_local_get(else_body, local_idx)
      }
      @lib.Instruction::If(_, then_body, None) =>
        count += lcse_test_count_local_get(then_body, local_idx)
      @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
        count += lcse_test_count_local_get(body, local_idx)
      _ => ()
    }
  }
  count
}

///|
fn lcse_test_count_global_get(
  instrs : Array[@lib.Instruction],
  global_idx : @lib.GlobalIdx,
) -> Int {
  let mut count = 0
  for instr in instrs {
    match instr {
      @lib.Instruction::GlobalGet(idx) => if idx == global_idx { count += 1 }
      @lib.Instruction::Block(_, @lib.Expr(body))
      | @lib.Instruction::Loop(_, @lib.Expr(body)) =>
        count += lcse_test_count_global_get(body, global_idx)
      @lib.Instruction::If(_, then_body, Some(else_body)) => {
        count += lcse_test_count_global_get(then_body, global_idx)
        count += lcse_test_count_global_get(else_body, global_idx)
      }
      @lib.Instruction::If(_, then_body, None) =>
        count += lcse_test_count_global_get(then_body, global_idx)
      @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
        count += lcse_test_count_global_get(body, global_idx)
      _ => ()
    }
  }
  count
}

///|
fn lcse_test_count_array_new(
  instrs : Array[@lib.Instruction],
  type_idx : @lib.TypeIdx,
) -> Int {
  let mut count = 0
  for instr in instrs {
    match instr {
      @lib.Instruction::ArrayNew(idx) => if idx == type_idx { count += 1 }
      @lib.Instruction::Block(_, @lib.Expr(body))
      | @lib.Instruction::Loop(_, @lib.Expr(body)) =>
        count += lcse_test_count_array_new(body, type_idx)
      @lib.Instruction::If(_, then_body, Some(else_body)) => {
        count += lcse_test_count_array_new(then_body, type_idx)
        count += lcse_test_count_array_new(else_body, type_idx)
      }
      @lib.Instruction::If(_, then_body, None) =>
        count += lcse_test_count_array_new(then_body, type_idx)
      @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
        count += lcse_test_count_array_new(body, type_idx)
      _ => ()
    }
  }
  count
}

///|
fn lcse_test_count_array_new_default(
  instrs : Array[@lib.Instruction],
  type_idx : @lib.TypeIdx,
) -> Int {
  let mut count = 0
  for instr in instrs {
    match instr {
      @lib.Instruction::ArrayNewDefault(idx) =>
        if idx == type_idx {
          count += 1
        }
      @lib.Instruction::Block(_, @lib.Expr(body))
      | @lib.Instruction::Loop(_, @lib.Expr(body)) =>
        count += lcse_test_count_array_new_default(body, type_idx)
      @lib.Instruction::If(_, then_body, Some(else_body)) => {
        count += lcse_test_count_array_new_default(then_body, type_idx)
        count += lcse_test_count_array_new_default(else_body, type_idx)
      }
      @lib.Instruction::If(_, then_body, None) =>
        count += lcse_test_count_array_new_default(then_body, type_idx)
      @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
        count += lcse_test_count_array_new_default(body, type_idx)
      _ => ()
    }
  }
  count
}

///|
fn lcse_test_count_array_new_fixed(
  instrs : Array[@lib.Instruction],
  type_idx : @lib.TypeIdx,
) -> Int {
  let mut count = 0
  for instr in instrs {
    match instr {
      @lib.Instruction::ArrayNewFixed(idx, _) =>
        if idx == type_idx {
          count += 1
        }
      @lib.Instruction::Block(_, @lib.Expr(body))
      | @lib.Instruction::Loop(_, @lib.Expr(body)) =>
        count += lcse_test_count_array_new_fixed(body, type_idx)
      @lib.Instruction::If(_, then_body, Some(else_body)) => {
        count += lcse_test_count_array_new_fixed(then_body, type_idx)
        count += lcse_test_count_array_new_fixed(else_body, type_idx)
      }
      @lib.Instruction::If(_, then_body, None) =>
        count += lcse_test_count_array_new_fixed(then_body, type_idx)
      @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
        count += lcse_test_count_array_new_fixed(body, type_idx)
      _ => ()
    }
  }
  count
}

///|
fn lcse_test_count_array_new_data(
  instrs : Array[@lib.Instruction],
  type_idx : @lib.TypeIdx,
  data_idx : @lib.DataIdx,
) -> Int {
  let mut count = 0
  for instr in instrs {
    match instr {
      @lib.Instruction::ArrayNewData(ti, di) =>
        if ti == type_idx && di == data_idx {
          count += 1
        }
      @lib.Instruction::Block(_, @lib.Expr(body))
      | @lib.Instruction::Loop(_, @lib.Expr(body)) =>
        count += lcse_test_count_array_new_data(body, type_idx, data_idx)
      @lib.Instruction::If(_, then_body, Some(else_body)) => {
        count += lcse_test_count_array_new_data(then_body, type_idx, data_idx)
        count += lcse_test_count_array_new_data(else_body, type_idx, data_idx)
      }
      @lib.Instruction::If(_, then_body, None) =>
        count += lcse_test_count_array_new_data(then_body, type_idx, data_idx)
      @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
        count += lcse_test_count_array_new_data(body, type_idx, data_idx)
      _ => ()
    }
  }
  count
}

///|
fn lcse_test_count_array_new_elem(
  instrs : Array[@lib.Instruction],
  type_idx : @lib.TypeIdx,
  elem_idx : @lib.ElemIdx,
) -> Int {
  let mut count = 0
  for instr in instrs {
    match instr {
      @lib.Instruction::ArrayNewElem(ti, ei) =>
        if ti == type_idx && ei == elem_idx {
          count += 1
        }
      @lib.Instruction::Block(_, @lib.Expr(body))
      | @lib.Instruction::Loop(_, @lib.Expr(body)) =>
        count += lcse_test_count_array_new_elem(body, type_idx, elem_idx)
      @lib.Instruction::If(_, then_body, Some(else_body)) => {
        count += lcse_test_count_array_new_elem(then_body, type_idx, elem_idx)
        count += lcse_test_count_array_new_elem(else_body, type_idx, elem_idx)
      }
      @lib.Instruction::If(_, then_body, None) =>
        count += lcse_test_count_array_new_elem(then_body, type_idx, elem_idx)
      @lib.Instruction::TryTable(_, _, @lib.Expr(body)) =>
        count += lcse_test_count_array_new_elem(body, type_idx, elem_idx)
      _ => ()
    }
  }
  count
}

///|
test "local-cse registers as an active module pass" {
  match pass_registry_lookup("local-cse") {
    Some(entry) => {
      @debug.assert_eq(entry.category, HotPassRegistryCategory::module_pass())
      @debug.assert_eq(entry.descriptor, None)
    }
    None => fail("expected local-cse registry entry")
  }
}

///|
test "local-cse reuses repeated same-window arithmetic trees" {
  let input =
    #| (module
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_true(
    instrs.contains(@lib.Instruction::local_tee(@lib.LocalIdx::new(2U))),
  )
  assert_true(
    instrs.contains(@lib.Instruction::local_get(@lib.LocalIdx::new(2U))),
  )
}

///|
test "local-cse reuses local-only expression across integer comparison" {
  let input =
    #| (module
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (drop (i32.lt_s (local.get 0) (local.get 1)))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated integer comparison roots" {
  let input =
    #| (module
    #|   (func (param i32 i32)
    #|     (drop (i32.lt_s (local.get 0) (local.get 1)))
    #|     (drop (i32.lt_s (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated integer equality roots" {
  let input =
    #| (module
    #|   (func (param i32 i32 i64 i64)
    #|     (drop (i32.eq (local.get 0) (local.get 1)))
    #|     (drop (i32.eq (local.get 0) (local.get 1)))
    #|     (drop (i64.ne (local.get 2) (local.get 3)))
    #|     (drop (i64.ne (local.get 2) (local.get 3)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(4U)), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, @lib.LocalIdx::new(4U)), 1)
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(5U)), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, @lib.LocalIdx::new(5U)), 1)
}

///|
test "local-cse reuses local-only expression across integer eqz" {
  let input =
    #| (module
    #|   (func (param i32 i32 i64)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (drop (i64.eqz (local.get 2)))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(3U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated integer eqz roots" {
  let input =
    #| (module
    #|   (func (param i64)
    #|     (drop (i64.eqz (local.get 0)))
    #|     (drop (i64.eqz (local.get 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(1U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated integer division roots" {
  let func_type_i32_idx = @lib.TypeIdx::new(0U)
  let func_type_i64_idx = @lib.TypeIdx::new(1U)
  let func_types = [
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i64(), @lib.ValType::i64()], []),
      ),
    ),
  ]
  let body_for = fn(op : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        op,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        op,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new(func_types))
    .with_func_sec(
      @lib.FuncSec::new([
        func_type_i32_idx, func_type_i32_idx, func_type_i64_idx, func_type_i64_idx,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        body_for(@lib.Instruction::i32_div_s()),
        body_for(@lib.Instruction::i32_div_u()),
        body_for(@lib.Instruction::i64_div_s()),
        body_for(@lib.Instruction::i64_div_u()),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      @debug.assert_eq(funcs.length(), 4)
      for i = 0; i < funcs.length(); i = i + 1 {
        let @lib.Func(locals, @lib.Expr(instrs)) = funcs[i]
        let expected_ty = if i < 2 {
          @lib.ValType::i32()
        } else {
          @lib.ValType::i64()
        }
        let temp = @lib.LocalIdx::new(2U)
        @debug.assert_eq(locals, @lib.Locals::from_types([expected_ty]))
        @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
        @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
      }
    }
    None => fail("expected code section")
  }
}

///|
test "local-cse reuses repeated integer remainder roots" {
  let func_type_i32_idx = @lib.TypeIdx::new(0U)
  let func_type_i64_idx = @lib.TypeIdx::new(1U)
  let func_types = [
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::i64(), @lib.ValType::i64()], []),
      ),
    ),
  ]
  let body_for = fn(op : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        op,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        op,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new(func_types))
    .with_func_sec(
      @lib.FuncSec::new([
        func_type_i32_idx, func_type_i32_idx, func_type_i64_idx, func_type_i64_idx,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        body_for(@lib.Instruction::i32_rem_s()),
        body_for(@lib.Instruction::i32_rem_u()),
        body_for(@lib.Instruction::i64_rem_s()),
        body_for(@lib.Instruction::i64_rem_u()),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      @debug.assert_eq(funcs.length(), 4)
      for i = 0; i < funcs.length(); i = i + 1 {
        let @lib.Func(locals, @lib.Expr(instrs)) = funcs[i]
        let expected_ty = if i < 2 {
          @lib.ValType::i32()
        } else {
          @lib.ValType::i64()
        }
        let temp = @lib.LocalIdx::new(2U)
        @debug.assert_eq(locals, @lib.Locals::from_types([expected_ty]))
        @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
        @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
      }
    }
    None => fail("expected code section")
  }
}

///|
test "local-cse reuses repeated trapping float-to-int trunc roots" {
  let func_type_f32_idx = @lib.TypeIdx::new(0U)
  let func_type_f64_idx = @lib.TypeIdx::new(1U)
  let func_types = [
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::f32()], [])),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::f64()], [])),
    ),
  ]
  let body_for = fn(op : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        op,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        op,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new(func_types))
    .with_func_sec(
      @lib.FuncSec::new([
        func_type_f32_idx, func_type_f32_idx, func_type_f64_idx, func_type_f64_idx,
        func_type_f32_idx, func_type_f32_idx, func_type_f64_idx, func_type_f64_idx,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        body_for(@lib.Instruction::i32_trunc_f32s()),
        body_for(@lib.Instruction::i32_trunc_f32u()),
        body_for(@lib.Instruction::i32_trunc_f64s()),
        body_for(@lib.Instruction::i32_trunc_f64u()),
        body_for(@lib.Instruction::i64_trunc_f32s()),
        body_for(@lib.Instruction::i64_trunc_f32u()),
        body_for(@lib.Instruction::i64_trunc_f64s()),
        body_for(@lib.Instruction::i64_trunc_f64u()),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      @debug.assert_eq(funcs.length(), 8)
      for i = 0; i < funcs.length(); i = i + 1 {
        let @lib.Func(locals, @lib.Expr(instrs)) = funcs[i]
        let expected_ty = if i < 4 {
          @lib.ValType::i32()
        } else {
          @lib.ValType::i64()
        }
        let temp = @lib.LocalIdx::new(1U)
        @debug.assert_eq(locals, @lib.Locals::from_types([expected_ty]))
        @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
        @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
      }
    }
    None => fail("expected code section")
  }
}

///|
test "local-cse reuses local-only expression across integer unary bit op" {
  let input =
    #| (module
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (drop (i32.clz (local.get 0)))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated integer binary bit op roots" {
  let input =
    #| (module
    #|   (func (param i32 i32)
    #|     (drop (i32.and (local.get 0) (local.get 1)))
    #|     (drop (i32.and (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses local-only expression across float arithmetic" {
  let input =
    #| (module
    #|   (func (param i32 i32 f32 f32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (drop (f32.add (local.get 2) (local.get 3)))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(4U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated float arithmetic roots" {
  let input =
    #| (module
    #|   (func (param f32 f32)
    #|     (drop (f32.add (local.get 0) (local.get 1)))
    #|     (drop (f32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::f32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated float comparison roots" {
  let input =
    #| (module
    #|   (func (param f32 f32)
    #|     (drop (f32.lt (local.get 0) (local.get 1)))
    #|     (drop (f32.lt (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses local-only expression across float equality" {
  let input =
    #| (module
    #|   (func (param i32 i32 f64 f64)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (drop (f64.ne (local.get 2) (local.get 3)))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(4U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated float equality roots" {
  let input =
    #| (module
    #|   (func (param f32 f32 f64 f64)
    #|     (drop (f32.eq (local.get 0) (local.get 1)))
    #|     (drop (f32.eq (local.get 0) (local.get 1)))
    #|     (drop (f64.ne (local.get 2) (local.get 3)))
    #|     (drop (f64.ne (local.get 2) (local.get 3)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  for temp in [@lib.LocalIdx::new(4U), @lib.LocalIdx::new(5U)] {
    @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
    @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
  }
}

///|
test "local-cse reuses repeated SIMD pure roots" {
  let v128_ty = @lib.ValType::v128()
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([v128_ty, v128_ty], [])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::v128_not(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::v128_not(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i8x16_eq(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i8x16_eq(),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([v128_ty, v128_ty]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(2U)), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, @lib.LocalIdx::new(2U)), 1)
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(3U)), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, @lib.LocalIdx::new(3U)), 1)
}

///|
test "local-cse reuses repeated SIMD comparison roots" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::v128(), @lib.ValType::v128()], []),
    ),
  )
  let body_for = fn(op : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        op,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        op,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        body_for(@lib.Instruction::i8x16_ne()),
        body_for(@lib.Instruction::i8x16_lt_s()),
        body_for(@lib.Instruction::i8x16_gt_u()),
        body_for(@lib.Instruction::i16x8_eq()),
        body_for(@lib.Instruction::i16x8_le_u()),
        body_for(@lib.Instruction::i32x4_ne()),
        body_for(@lib.Instruction::i32x4_ge_s()),
        body_for(@lib.Instruction::i64x2_eq()),
        body_for(@lib.Instruction::i64x2_ge_s()),
        body_for(@lib.Instruction::f32x4_eq()),
        body_for(@lib.Instruction::f32x4_ne()),
        body_for(@lib.Instruction::f32x4_lt()),
        body_for(@lib.Instruction::f32x4_ge()),
        body_for(@lib.Instruction::f64x2_eq()),
        body_for(@lib.Instruction::f64x2_ne()),
        body_for(@lib.Instruction::f64x2_ge()),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        ignore(locals)
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 1)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse reuses repeated SIMD splat roots" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_types = [
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i64()], [])),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::f32()], [])),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::f64()], [])),
    ),
  ]
  let body_for = fn(splat : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        splat,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        splat,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new(func_types))
    .with_func_sec(
      @lib.FuncSec::new([
        func_type_idx,
        func_type_idx,
        func_type_idx,
        @lib.TypeIdx::new(1U),
        @lib.TypeIdx::new(2U),
        @lib.TypeIdx::new(3U),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        body_for(@lib.Instruction::i8x16_splat()),
        body_for(@lib.Instruction::i16x8_splat()),
        body_for(@lib.Instruction::i32x4_splat()),
        body_for(@lib.Instruction::i64x2_splat()),
        body_for(@lib.Instruction::f32x4_splat()),
        body_for(@lib.Instruction::f64x2_splat()),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        ignore(locals)
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 1)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse reuses repeated SIMD replace-lane roots" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let lane = @lib.LaneIdx::new(0)
  let func_types = [
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::v128(), @lib.ValType::i32()], []),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::v128(), @lib.ValType::i64()], []),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::v128(), @lib.ValType::f32()], []),
      ),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func([@lib.ValType::v128(), @lib.ValType::f64()], []),
      ),
    ),
  ]
  let body_for = fn(replace : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        replace,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        replace,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new(func_types))
    .with_func_sec(
      @lib.FuncSec::new([
        func_type_idx,
        func_type_idx,
        func_type_idx,
        @lib.TypeIdx::new(1U),
        @lib.TypeIdx::new(2U),
        @lib.TypeIdx::new(3U),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        body_for(@lib.Instruction::i8x16_replace_lane(lane)),
        body_for(@lib.Instruction::i16x8_replace_lane(lane)),
        body_for(@lib.Instruction::i32x4_replace_lane(lane)),
        body_for(@lib.Instruction::i64x2_replace_lane(lane)),
        body_for(@lib.Instruction::f32x4_replace_lane(lane)),
        body_for(@lib.Instruction::f64x2_replace_lane(lane)),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        ignore(locals)
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 1)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse reuses repeated SIMD shuffle and swizzle roots" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::v128(), @lib.ValType::v128()], []),
    ),
  )
  let body_for = fn(op : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        op,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        op,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx, func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        body_for(
          @lib.Instruction::i8x16_shuffle(
            @lib.LaneIdx::new(0),
            @lib.LaneIdx::new(1),
            @lib.LaneIdx::new(2),
            @lib.LaneIdx::new(3),
            @lib.LaneIdx::new(4),
            @lib.LaneIdx::new(5),
            @lib.LaneIdx::new(6),
            @lib.LaneIdx::new(7),
            @lib.LaneIdx::new(16),
            @lib.LaneIdx::new(17),
            @lib.LaneIdx::new(18),
            @lib.LaneIdx::new(19),
            @lib.LaneIdx::new(20),
            @lib.LaneIdx::new(21),
            @lib.LaneIdx::new(22),
            @lib.LaneIdx::new(23),
          ),
        ),
        body_for(@lib.Instruction::i8x16_swizzle()),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        ignore(locals)
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 1)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse reuses repeated SIMD any-true all-true and bitmask roots" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::v128()], [])),
  )
  let body_for = fn(op : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        op,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        op,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx, func_type_idx, func_type_idx, func_type_idx,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        body_for(@lib.Instruction::v128_any_true()),
        body_for(@lib.Instruction::i8x16_all_true()),
        body_for(@lib.Instruction::i16x8_all_true()),
        body_for(@lib.Instruction::i32x4_all_true()),
        body_for(@lib.Instruction::i64x2_all_true()),
        body_for(@lib.Instruction::i8x16_bitmask()),
        body_for(@lib.Instruction::i16x8_bitmask()),
        body_for(@lib.Instruction::i32x4_bitmask()),
        body_for(@lib.Instruction::i64x2_bitmask()),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        ignore(locals)
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 1)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse reuses repeated wider SIMD arithmetic and logic roots" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func(
        [@lib.ValType::v128(), @lib.ValType::v128(), @lib.ValType::v128()],
        [],
      ),
    ),
  )
  let unary_body_for = fn(op : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        op,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        op,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let binary_body_for = fn(op : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        op,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        op,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let ternary_body_for = fn(op : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        op,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        op,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx, func_type_idx, func_type_idx, func_type_idx,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        binary_body_for(@lib.Instruction::v128_and()),
        binary_body_for(@lib.Instruction::v128_xor()),
        ternary_body_for(@lib.Instruction::v128_bitselect()),
        unary_body_for(@lib.Instruction::i8x16_abs()),
        unary_body_for(@lib.Instruction::i16x8_neg()),
        binary_body_for(@lib.Instruction::i32x4_add()),
        binary_body_for(@lib.Instruction::i64x2_mul()),
        unary_body_for(@lib.Instruction::f32x4_sqrt()),
        binary_body_for(@lib.Instruction::f64x2_add()),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        ignore(locals)
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 1)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse reuses repeated SIMD extended integer arithmetic roots" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func(
        [@lib.ValType::v128(), @lib.ValType::v128(), @lib.ValType::i32()],
        [],
      ),
    ),
  )
  let binary_body_for = fn(op : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        op,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        op,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let shift_body_for = fn(op : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        op,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        op,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx, func_type_idx, func_type_idx, func_type_idx,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        binary_body_for(@lib.Instruction::i8x16_add_sat_s()),
        binary_body_for(@lib.Instruction::i8x16_sub_sat_u()),
        binary_body_for(@lib.Instruction::i8x16_min_s()),
        binary_body_for(@lib.Instruction::i8x16_avgr_u()),
        binary_body_for(@lib.Instruction::i16x8_add_sat_u()),
        binary_body_for(@lib.Instruction::i16x8q15mulr_sat_s()),
        binary_body_for(@lib.Instruction::i16x8_avgr_u()),
        binary_body_for(@lib.Instruction::i16x8_extmul_high_i8x16u()),
        shift_body_for(@lib.Instruction::i32x4_shl()),
        binary_body_for(@lib.Instruction::i32x4_min_u()),
        binary_body_for(@lib.Instruction::i32x4_dot_i16x8s()),
        binary_body_for(@lib.Instruction::i32x4_extmul_low_i16x8s()),
        shift_body_for(@lib.Instruction::i64x2_shr_u()),
        binary_body_for(@lib.Instruction::i64x2_extmul_high_i32x4u()),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        ignore(locals)
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 1)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse reuses repeated SIMD float min max roots" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::v128(), @lib.ValType::v128()], []),
    ),
  )
  let body_for = fn(op : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        op,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        op,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx, func_type_idx, func_type_idx,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        body_for(@lib.Instruction::f32x4_min()),
        body_for(@lib.Instruction::f32x4_max()),
        body_for(@lib.Instruction::f32x4_pmin()),
        body_for(@lib.Instruction::f32x4_pmax()),
        body_for(@lib.Instruction::f64x2_min()),
        body_for(@lib.Instruction::f64x2_max()),
        body_for(@lib.Instruction::f64x2_pmin()),
        body_for(@lib.Instruction::f64x2_pmax()),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        ignore(locals)
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 1)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse reuses repeated SIMD float rounding roots" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::v128()], [])),
  )
  let body_for = fn(op : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        op,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        op,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx, func_type_idx, func_type_idx,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        body_for(@lib.Instruction::f32x4_ceil()),
        body_for(@lib.Instruction::f32x4_floor()),
        body_for(@lib.Instruction::f32x4_trunc()),
        body_for(@lib.Instruction::f32x4_nearest()),
        body_for(@lib.Instruction::f64x2_ceil()),
        body_for(@lib.Instruction::f64x2_floor()),
        body_for(@lib.Instruction::f64x2_trunc()),
        body_for(@lib.Instruction::f64x2_nearest()),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        ignore(locals)
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 1)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse reuses repeated SIMD widening and narrowing roots" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::v128(), @lib.ValType::v128()], []),
    ),
  )
  let unary_body_for = fn(op : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        op,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        op,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let binary_body_for = fn(op : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        op,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        op,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        binary_body_for(@lib.Instruction::i8x16_narrow_i16x8s()),
        binary_body_for(@lib.Instruction::i8x16_narrow_i16x8u()),
        binary_body_for(@lib.Instruction::i16x8_narrow_i32x4s()),
        binary_body_for(@lib.Instruction::i16x8_narrow_i32x4u()),
        unary_body_for(@lib.Instruction::i16x8_extadd_pairwise_i8x16s()),
        unary_body_for(@lib.Instruction::i16x8_extadd_pairwise_i8x16u()),
        unary_body_for(@lib.Instruction::i32x4_extadd_pairwise_i16x8s()),
        unary_body_for(@lib.Instruction::i32x4_extadd_pairwise_i16x8u()),
        unary_body_for(@lib.Instruction::i16x8_extend_low_i8x16s()),
        unary_body_for(@lib.Instruction::i16x8_extend_high_i8x16s()),
        unary_body_for(@lib.Instruction::i16x8_extend_low_i8x16u()),
        unary_body_for(@lib.Instruction::i16x8_extend_high_i8x16u()),
        unary_body_for(@lib.Instruction::i32x4_extend_low_i16x8s()),
        unary_body_for(@lib.Instruction::i32x4_extend_high_i16x8s()),
        unary_body_for(@lib.Instruction::i32x4_extend_low_i16x8u()),
        unary_body_for(@lib.Instruction::i32x4_extend_high_i16x8u()),
        unary_body_for(@lib.Instruction::i64x2_extend_low_i32x4s()),
        unary_body_for(@lib.Instruction::i64x2_extend_high_i32x4s()),
        unary_body_for(@lib.Instruction::i64x2_extend_low_i32x4u()),
        unary_body_for(@lib.Instruction::i64x2_extend_high_i32x4u()),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        ignore(locals)
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 1)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse reuses repeated SIMD conversion roots" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::v128()], [])),
  )
  let body_for = fn(op : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        op,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        op,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        body_for(@lib.Instruction::f32x4_demote_f64x2_zero()),
        body_for(@lib.Instruction::f64x2_promote_low_f32x4()),
        body_for(@lib.Instruction::i32x4_trunc_sat_f32x4s()),
        body_for(@lib.Instruction::i32x4_trunc_sat_f32x4u()),
        body_for(@lib.Instruction::f32x4_convert_i32x4s()),
        body_for(@lib.Instruction::f32x4_convert_i32x4u()),
        body_for(@lib.Instruction::i32x4_trunc_sat_f64x2s_zero()),
        body_for(@lib.Instruction::i32x4_trunc_sat_f64x2u_zero()),
        body_for(@lib.Instruction::f64x2_convert_low_i32x4s()),
        body_for(@lib.Instruction::f64x2_convert_low_i32x4u()),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        ignore(locals)
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 1)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse defers repeated relaxed SIMD roots" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func(
        [@lib.ValType::v128(), @lib.ValType::v128(), @lib.ValType::v128()],
        [],
      ),
    ),
  )
  let unary_body_for = fn(op : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        op,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        op,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let binary_body_for = fn(op : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        op,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        op,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let ternary_body_for = fn(op : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        op,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        op,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        binary_body_for(@lib.Instruction::i8x16_relaxed_swizzle()),
        unary_body_for(@lib.Instruction::i32x4_relaxed_trunc_f32x4s()),
        unary_body_for(@lib.Instruction::i32x4_relaxed_trunc_f32x4u()),
        unary_body_for(@lib.Instruction::i32x4_relaxed_trunc_zero_f64x2s()),
        unary_body_for(@lib.Instruction::i32x4_relaxed_trunc_zero_f64x2u()),
        ternary_body_for(@lib.Instruction::f32x4_relaxed_madd()),
        ternary_body_for(@lib.Instruction::f32x4_relaxed_nmadd()),
        ternary_body_for(@lib.Instruction::f64x2_relaxed_madd()),
        ternary_body_for(@lib.Instruction::f64x2_relaxed_nmadd()),
        ternary_body_for(@lib.Instruction::i8x16_relaxed_laneselect()),
        ternary_body_for(@lib.Instruction::i16x8_relaxed_laneselect()),
        ternary_body_for(@lib.Instruction::i32x4_relaxed_laneselect()),
        ternary_body_for(@lib.Instruction::i64x2_relaxed_laneselect()),
        binary_body_for(@lib.Instruction::f32x4_relaxed_min()),
        binary_body_for(@lib.Instruction::f32x4_relaxed_max()),
        binary_body_for(@lib.Instruction::f64x2_relaxed_min()),
        binary_body_for(@lib.Instruction::f64x2_relaxed_max()),
        binary_body_for(@lib.Instruction::i16x8_relaxed_q15mulr_s()),
        binary_body_for(@lib.Instruction::i16x8_relaxed_dot_i8x16i7x16s()),
        ternary_body_for(@lib.Instruction::i32x4_relaxed_dot_i8x16i7x16_add_s()),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        @debug.assert_eq(locals, @lib.Locals::from_types([]))
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 0)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse reuses repeated SIMD lane-extract roots" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let lane = @lib.LaneIdx::new(0)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::v128()], [])),
  )
  let body_for = fn(extract : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        extract,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        extract,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        body_for(@lib.Instruction::i8x16_extract_lane_s(lane)),
        body_for(@lib.Instruction::i16x8_extract_lane_u(lane)),
        body_for(@lib.Instruction::i32x4_extract_lane(lane)),
        body_for(@lib.Instruction::i64x2_extract_lane(lane)),
        body_for(@lib.Instruction::f32x4_extract_lane(lane)),
        body_for(@lib.Instruction::f64x2_extract_lane(lane)),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        ignore(locals)
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 1)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse defers repeated SIMD load roots" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let memarg = @lib.MemArg::new(@lib.U32(4U), None, @lib.U64(0UL))
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::v128_load(memarg),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::v128_load(memarg),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(1U)), 0)
}

///|
test "local-cse defers repeated SIMD lane-load roots" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let memarg = @lib.MemArg::new(@lib.U32(0U), None, @lib.U64(0UL))
  let lane = @lib.LaneIdx::new(0)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::v128()], []),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::v128_load8_lane(memarg, lane),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::v128_load8_lane(memarg, lane),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(2U)), 0)
}

///|
test "local-cse defers repeated wider SIMD lane-load roots" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let memarg = @lib.MemArg::new(@lib.U32(0U), None, @lib.U64(0UL))
  let lane = @lib.LaneIdx::new(0)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::v128()], []),
    ),
  )
  let body_for = fn(load : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        load,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        load,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(
      @lib.FuncSec::new([func_type_idx, func_type_idx, func_type_idx]),
    )
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        body_for(@lib.Instruction::v128_load16_lane(memarg, lane)),
        body_for(@lib.Instruction::v128_load32_lane(memarg, lane)),
        body_for(@lib.Instruction::v128_load64_lane(memarg, lane)),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        @debug.assert_eq(locals, @lib.Locals::from_types([]))
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 0)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse defers repeated SIMD load splat and zero roots" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let memarg = @lib.MemArg::new(@lib.U32(0U), None, @lib.U64(0UL))
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let body_for = fn(load : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        load,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        load,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx,
      ]),
    )
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        body_for(@lib.Instruction::v128_load8_splat(memarg)),
        body_for(@lib.Instruction::v128_load16_splat(memarg)),
        body_for(@lib.Instruction::v128_load32_splat(memarg)),
        body_for(@lib.Instruction::v128_load64_splat(memarg)),
        body_for(@lib.Instruction::v128_load32_zero(memarg)),
        body_for(@lib.Instruction::v128_load64_zero(memarg)),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        @debug.assert_eq(locals, @lib.Locals::from_types([]))
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 0)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse defers repeated SIMD load extend roots" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let memarg = @lib.MemArg::new(@lib.U32(0U), None, @lib.U64(0UL))
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let body_for = fn(load : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        load,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        load,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx,
      ]),
    )
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        body_for(@lib.Instruction::v128_load8x8s(memarg)),
        body_for(@lib.Instruction::v128_load8x8u(memarg)),
        body_for(@lib.Instruction::v128_load16x4s(memarg)),
        body_for(@lib.Instruction::v128_load16x4u(memarg)),
        body_for(@lib.Instruction::v128_load32x2s(memarg)),
        body_for(@lib.Instruction::v128_load32x2u(memarg)),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        @debug.assert_eq(locals, @lib.Locals::from_types([]))
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 0)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse defers local-only scalar reuse across SIMD stores" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let memarg = @lib.MemArg::new(@lib.U32(0U), None, @lib.U64(0UL))
  let lane = @lib.LaneIdx::new(0)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func(
        [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::v128()],
        [],
      ),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx, func_type_idx]))
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::v128_store(memarg),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_mul(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::v128_store8_lane(memarg, lane),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_mul(),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        @debug.assert_eq(locals, @lib.Locals::from_types([]))
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 0)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse defers local-only scalar reuse across wider SIMD lane stores" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let memarg = @lib.MemArg::new(@lib.U32(0U), None, @lib.U64(0UL))
  let lane = @lib.LaneIdx::new(0)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func(
        [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::v128()],
        [],
      ),
    ),
  )
  let body_for = fn(store : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
        store,
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(
      @lib.FuncSec::new([func_type_idx, func_type_idx, func_type_idx]),
    )
    .with_mem_sec(
      @lib.MemSec::new([@lib.MemType::new(@lib.Limits::i32(1U, None))]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        body_for(@lib.Instruction::v128_store16_lane(memarg, lane)),
        body_for(@lib.Instruction::v128_store32_lane(memarg, lane)),
        body_for(@lib.Instruction::v128_store64_lane(memarg, lane)),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        @debug.assert_eq(locals, @lib.Locals::from_types([]))
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 0)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse defers repeated packed struct atomic get roots" {
  let struct_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let ref_ty = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(struct_type_idx)),
  )
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::pack_type(@lib.PackType::i8()),
          @lib.Mut::var_(),
        ),
        @lib.FieldType::new(
          @lib.StorageType::pack_type(@lib.PackType::i16()),
          @lib.Mut::var_(),
        ),
      ]),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([ref_ty], [])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::struct_atomic_get_s(
              @lib.AtomicOrder::seq_cst(),
              struct_type_idx,
              @lib.U32(0U),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::struct_atomic_get_s(
              @lib.AtomicOrder::seq_cst(),
              struct_type_idx,
              @lib.U32(0U),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::struct_atomic_get_u(
              @lib.AtomicOrder::acq_rel(),
              struct_type_idx,
              @lib.U32(1U),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::struct_atomic_get_u(
              @lib.AtomicOrder::acq_rel(),
              struct_type_idx,
              @lib.U32(1U),
            ),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 0)
}

///|
test "local-cse reuses local-only expression across select" {
  let input =
    #| (module
    #|   (func (param i32 i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (drop (select (local.get 0) (local.get 1) (local.get 2)))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(3U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated select roots" {
  let input =
    #| (module
    #|   (func (param i32 i32 i32)
    #|     (drop (select (local.get 0) (local.get 1) (local.get 2)))
    #|     (drop (select (local.get 0) (local.get 1) (local.get 2)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(3U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses local-only expression across ref-is-null" {
  let input =
    #| (module
    #|   (func (param i32 i32 funcref)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (drop (ref.is_null (local.get 2)))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(3U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated ref-is-null roots" {
  let input =
    #| (module
    #|   (func (param funcref)
    #|     (drop (ref.is_null (local.get 0)))
    #|     (drop (ref.is_null (local.get 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(1U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse leaves repeated ref-null roots unmaterialized" {
  let input =
    #| (module
    #|   (func
    #|     (drop (ref.null eq))
    #|     (drop (ref.null eq))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 0)
}

///|
test "local-cse reuses repeated ref-i31 roots by caching i32 operand" {
  let input =
    #| (module
    #|   (func (param i32)
    #|     (drop (ref.i31 (local.get 0)))
    #|     (drop (ref.i31 (local.get 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(1U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_ref_i31(instrs), 2)
}

///|
test "local-cse reuses repeated i31 get roots" {
  let input =
    #| (module
    #|   (func (param (ref i31))
    #|     (drop (i31.get_s (local.get 0)))
    #|     (drop (i31.get_s (local.get 0)))
    #|     (drop (i31.get_u (local.get 0)))
    #|     (drop (i31.get_u (local.get 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  for temp in [@lib.LocalIdx::new(1U), @lib.LocalIdx::new(2U)] {
    @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
    @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
  }
}

///|
test "local-cse reuses repeated ref-test predicate roots" {
  let ref_ty = @lib.ValType::ref_null(
    @lib.HeapType::abs(@lib.AbsHeapType::any()),
  )
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([ref_ty], [])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::eq()),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::eq()),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(
              false,
              @lib.HeapType::abs(@lib.AbsHeapType::any()),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test(
              false,
              @lib.HeapType::abs(@lib.AbsHeapType::any()),
            ),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  for temp in [@lib.LocalIdx::new(1U), @lib.LocalIdx::new(2U)] {
    @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
    @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
  }
}

///|
test "local-cse reuses repeated ref-as-non-null roots by caching nullable operand" {
  let input =
    #| (module
    #|   (func (param externref)
    #|     (drop (ref.as_non_null (local.get 0)))
    #|     (drop (ref.as_non_null (local.get 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(1U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::externref()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_ref_as_non_null(instrs), 2)
}

///|
test "local-cse leaves repeated string const roots unmaterialized" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::string_const(b"hello"),
            @lib.Instruction::drop(),
            @lib.Instruction::string_const(b"hello"),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(0U)), 0)
}

///|
test "local-cse leaves repeated ref.func roots unmaterialized" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx, func_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::from_types([]), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_defined_func(
    optimized, 1,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 0)
}

///|
test "local-cse defers repeated string new array roots" {
  let bytes_type_idx = @lib.TypeIdx::new(0U)
  let words_type_idx = @lib.TypeIdx::new(1U)
  let func_type_idx = @lib.TypeIdx::new(2U)
  let bytes_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::pack_type(@lib.PackType::i8()),
          @lib.Mut::const_(),
        ),
      ),
    ),
  )
  let words_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::pack_type(@lib.PackType::i16()),
          @lib.Mut::const_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func(
        [
          @lib.ValType::ref_array_nullable(bytes_type_idx),
          @lib.ValType::ref_array_nullable(words_type_idx),
        ],
        [],
      ),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([bytes_type, words_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::string_new_utf8_array(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::string_new_utf8_array(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::string_new_wtf16_array(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::string_new_wtf16_array(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::string_new_lossy_utf8_array(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::string_new_lossy_utf8_array(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::string_new_wtf8_array(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::string_new_wtf8_array(),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 0)
}

///|
test "local-cse defers repeated string encode array roots" {
  let bytes_type_idx = @lib.TypeIdx::new(0U)
  let words_type_idx = @lib.TypeIdx::new(1U)
  let func_type_idx = @lib.TypeIdx::new(2U)
  let bytes_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::pack_type(@lib.PackType::i8()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let words_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::pack_type(@lib.PackType::i16()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func(
        [
          @lib.ValType::stringref(),
          @lib.ValType::ref_array_nullable(bytes_type_idx),
          @lib.ValType::ref_array_nullable(words_type_idx),
        ],
        [],
      ),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([bytes_type, words_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::string_encode_utf8_array(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::string_encode_utf8_array(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::string_encode_wtf16_array(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::string_encode_wtf16_array(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::string_encode_lossy_utf8_array(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::string_encode_lossy_utf8_array(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::string_encode_wtf8_array(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::string_encode_wtf8_array(),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 0)
}

///|
test "local-cse reuses repeated reference conversion roots" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::externref(), @lib.ValType::anyref()], []),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::any_convert_extern(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::any_convert_extern(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::extern_convert_any(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::extern_convert_any(),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::anyref(), @lib.ValType::externref()]),
  )
  for temp in [@lib.LocalIdx::new(2U), @lib.LocalIdx::new(3U)] {
    @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
    @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
  }
}

///|
test "local-cse reuses repeated nullable ref-cast roots" {
  let ref_ty = @lib.ValType::ref_null(
    @lib.HeapType::abs(@lib.AbsHeapType::any()),
  )
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([ref_ty], [])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::eq()),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(
              true,
              @lib.HeapType::abs(@lib.AbsHeapType::eq()),
            ),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let expected_ty = @lib.ValType::ref_type(
    @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
  )
  let temp = @lib.LocalIdx::new(1U)
  @debug.assert_eq(locals, @lib.Locals::from_types([expected_ty]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated non-null ref-cast roots by caching nullable operand" {
  let ref_ty = @lib.ValType::ref_null(
    @lib.HeapType::abs(@lib.AbsHeapType::any()),
  )
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([ref_ty], [])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(
              false,
              @lib.HeapType::abs(@lib.AbsHeapType::eq()),
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast(
              false,
              @lib.HeapType::abs(@lib.AbsHeapType::eq()),
            ),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(1U)
  @debug.assert_eq(locals, @lib.Locals::from_types([ref_ty]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse defers repeated ref-get-desc roots" {
  let struct_type_idx = @lib.TypeIdx::new(0U)
  let desc_type_idx = @lib.TypeIdx::new(1U)
  let func_type_idx = @lib.TypeIdx::new(2U)
  let struct_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(struct_type_idx), exact=true),
  )
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([]),
      metadata=@lib.TypeMetadata::new(descriptor=Some(desc_type_idx)),
    ),
  )
  let desc_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([]),
      metadata=@lib.TypeMetadata::new(describes=Some(struct_type_idx)),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([struct_ref], [])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([struct_type, desc_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_get_desc(struct_type_idx),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_get_desc(struct_type_idx),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 0)
}

///|
test "local-cse defers repeated descriptor test and cast roots" {
  let ref_ty = @lib.ValType::funcref()
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([ref_ty], [])),
  )
  let desc_heap_type = @lib.HeapType::new(func_type_idx)
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test_desc(false, desc_heap_type),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_test_desc(false, desc_heap_type),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast_desc_eq(false, desc_heap_type),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_cast_desc_eq(false, desc_heap_type),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(1U)), 0)
}

///|
test "local-cse defers repeated descriptor allocation roots" {
  let struct_type_idx = @lib.TypeIdx::new(0U)
  let desc_type_idx = @lib.TypeIdx::new(1U)
  let func_type_idx = @lib.TypeIdx::new(2U)
  let desc_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(desc_type_idx)),
  )
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::const_(),
        ),
      ]),
      metadata=@lib.TypeMetadata::new(descriptor=Some(desc_type_idx)),
    ),
  )
  let desc_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([]),
      metadata=@lib.TypeMetadata::new(describes=Some(struct_type_idx)),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), desc_ref], []),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([struct_type, desc_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::struct_new_desc(struct_type_idx),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::struct_new_desc(struct_type_idx),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::struct_new_default_desc(struct_type_idx),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::struct_new_default_desc(struct_type_idx),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(2U)), 0)
}

///|
test "local-cse reuses local-only expression across numeric reinterpret" {
  let input =
    #| (module
    #|   (func (param i32 i32 f32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (drop (i32.reinterpret_f32 (local.get 2)))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(3U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated numeric reinterpret roots" {
  let input =
    #| (module
    #|   (func (param f32)
    #|     (drop (i32.reinterpret_f32 (local.get 0)))
    #|     (drop (i32.reinterpret_f32 (local.get 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(1U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated integer wrap roots" {
  let input =
    #| (module
    #|   (func (param i64)
    #|     (drop (i32.wrap_i64 (local.get 0)))
    #|     (drop (i32.wrap_i64 (local.get 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(1U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated integer widen roots" {
  let input =
    #| (module
    #|   (func (param i32)
    #|     (drop (i64.extend_i32_s (local.get 0)))
    #|     (drop (i64.extend_i32_s (local.get 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(1U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i64()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated float widen roots" {
  let input =
    #| (module
    #|   (func (param f32)
    #|     (drop (f64.promote_f32 (local.get 0)))
    #|     (drop (f64.promote_f32 (local.get 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(1U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::f64()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated float narrow roots" {
  let input =
    #| (module
    #|   (func (param f64)
    #|     (drop (f32.demote_f64 (local.get 0)))
    #|     (drop (f32.demote_f64 (local.get 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(1U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::f32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated integer-to-float conversion roots" {
  let func_type_i32_idx = @lib.TypeIdx::new(0U)
  let func_type_i64_idx = @lib.TypeIdx::new(1U)
  let func_types = [
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
    ),
    @lib.RecType::new(
      @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i64()], [])),
    ),
  ]
  let body_for = fn(op : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        op,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        op,
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new(func_types))
    .with_func_sec(
      @lib.FuncSec::new([
        func_type_i32_idx, func_type_i32_idx, func_type_i64_idx, func_type_i64_idx,
        func_type_i32_idx, func_type_i32_idx, func_type_i64_idx, func_type_i64_idx,
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        body_for(@lib.Instruction::f32_convert_i32s()),
        body_for(@lib.Instruction::f32_convert_i32u()),
        body_for(@lib.Instruction::f32_convert_i64s()),
        body_for(@lib.Instruction::f32_convert_i64u()),
        body_for(@lib.Instruction::f64_convert_i32s()),
        body_for(@lib.Instruction::f64_convert_i32u()),
        body_for(@lib.Instruction::f64_convert_i64s()),
        body_for(@lib.Instruction::f64_convert_i64u()),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) => {
      @debug.assert_eq(funcs.length(), 8)
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        let temp = @lib.LocalIdx::new(1U)
        @debug.assert_eq(locals.length(), 1)
        @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
        @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
      }
    }
    None => fail("expected code section")
  }
}

///|
test "local-cse reuses repeated i32 saturating trunc roots" {
  let input =
    #| (module
    #|   (func (param f32)
    #|     (drop (i32.trunc_sat_f32_s (local.get 0)))
    #|     (drop (i32.trunc_sat_f32_s (local.get 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(1U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated i64 saturating trunc roots" {
  let input =
    #| (module
    #|   (func (param f64)
    #|     (drop (i64.trunc_sat_f64_u (local.get 0)))
    #|     (drop (i64.trunc_sat_f64_u (local.get 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(1U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i64()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated i32 sign-extension roots" {
  let input =
    #| (module
    #|   (func (param i32)
    #|     (drop (i32.extend8_s (local.get 0)))
    #|     (drop (i32.extend8_s (local.get 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(1U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated i64 sign-extension roots" {
  let input =
    #| (module
    #|   (func (param i64)
    #|     (drop (i64.extend32_s (local.get 0)))
    #|     (drop (i64.extend32_s (local.get 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(1U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i64()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse prefers repeated parent trees over child trees" {
  let input =
    #| (module
    #|   (func (param i32 i32)
    #|     (drop (i32.eqz (i32.add (local.get 0) (local.get 1))))
    #|     (drop (i32.eqz (i32.add (local.get 0) (local.get 1))))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_true(
    instrs.contains(@lib.Instruction::local_tee(@lib.LocalIdx::new(2U))),
  )
}

///|
test "local-cse reuses repeated load trees until a store barrier" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (func (param i32)
    #|     (drop (i32.load (local.get 0)))
    #|     (drop (i32.load (local.get 0)))
    #|     (i32.store (local.get 0) (i32.const 1))
    #|     (drop (i32.load (local.get 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  assert_true(
    instrs.contains(@lib.Instruction::local_tee(@lib.LocalIdx::new(1U))),
  )
}

///|
test "local-cse reuses local-only expression across full-width non-i32 load" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (drop (f64.load (local.get 0)))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated i64 full-width load roots" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (func (param i32)
    #|     (drop (i64.load (local.get 0)))
    #|     (drop (i64.load (local.get 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(1U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i64()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated float full-width load roots" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (func (param i32)
    #|     (drop (f32.load (local.get 0)))
    #|     (drop (f32.load (local.get 0)))
    #|     (drop (f64.load (local.get 0)))
    #|     (drop (f64.load (local.get 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::f32(), @lib.ValType::f64()]),
  )
  for temp in [@lib.LocalIdx::new(1U), @lib.LocalIdx::new(2U)] {
    @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
    @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
  }
}

///|
test "local-cse reuses repeated i32 narrow load roots" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (func (param i32)
    #|     (drop (i32.load8_u (local.get 0)))
    #|     (drop (i32.load8_u (local.get 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(1U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated i64 narrow load roots" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (func (param i32)
    #|     (drop (i64.load32_u (local.get 0)))
    #|     (drop (i64.load32_u (local.get 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(1U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i64()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses local-only expression across memory-copy" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (memory.copy (i32.const 0) (i32.const 4) (i32.const 1))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse defers repeated struct and array get roots" {
  let struct_type_idx = @lib.TypeIdx::new(0U)
  let array_type_idx = @lib.TypeIdx::new(1U)
  let func_type_idx = @lib.TypeIdx::new(2U)
  let struct_ref = @lib.ValType::ref_null(@lib.HeapType::new(struct_type_idx))
  let array_ref = @lib.ValType::ref_null(@lib.HeapType::new(array_type_idx))
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ]),
    ),
  )
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([struct_ref, array_ref], [])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([struct_type, array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::struct_get(struct_type_idx, @lib.U32(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::struct_get(struct_type_idx, @lib.U32(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::array_get(array_type_idx),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::array_get(array_type_idx),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(2U)), 0)
}

///|
test "local-cse defers repeated array len roots" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::ref_array_nullable(array_type_idx)], []),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::array_len(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::array_len(),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(1U)), 0)
}

///|
test "local-cse defers repeated packed struct and array get roots" {
  let struct_type_idx = @lib.TypeIdx::new(0U)
  let array_type_idx = @lib.TypeIdx::new(1U)
  let func_type_idx = @lib.TypeIdx::new(2U)
  let struct_ref = @lib.ValType::ref_null(@lib.HeapType::new(struct_type_idx))
  let array_ref = @lib.ValType::ref_null(@lib.HeapType::new(array_type_idx))
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::pack_type(@lib.PackType::i8()),
          @lib.Mut::var_(),
        ),
        @lib.FieldType::new(
          @lib.StorageType::pack_type(@lib.PackType::i16()),
          @lib.Mut::var_(),
        ),
      ]),
    ),
  )
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::pack_type(@lib.PackType::i8()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([struct_ref, array_ref, @lib.ValType::i32()], []),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([struct_type, array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::struct_get_s(struct_type_idx, @lib.U32(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::struct_get_s(struct_type_idx, @lib.U32(0U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::struct_get_u(struct_type_idx, @lib.U32(1U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::struct_get_u(struct_type_idx, @lib.U32(1U)),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::array_get_s(array_type_idx),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::array_get_s(array_type_idx),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::array_get_u(array_type_idx),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::array_get_u(array_type_idx),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(3U)), 0)
}

///|
test "local-cse defers local-only reuse across linear atomic operations" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let memarg = @lib.MemArg::new(@lib.U32(2U), None, @lib.U64(0UL))
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_mem_sec(
      @lib.MemSec::new([
        @lib.MemType::new(@lib.Limits::i32(1U, Some(1U)), shared=true),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_atomic_load(memarg),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(1),
            @lib.Instruction::atomic_rmw(@lib.AtomicRmwOp::i32_add(), memarg),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(2U)), 0)
}

///|
test "local-cse defers local-only reuse across atomic load width variants" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let memarg8 = @lib.MemArg::new(@lib.U32(0U), None, @lib.U64(0UL))
  let memarg16 = @lib.MemArg::new(@lib.U32(1U), None, @lib.U64(2UL))
  let memarg32 = @lib.MemArg::new(@lib.U32(2U), None, @lib.U64(4UL))
  let memarg64 = @lib.MemArg::new(@lib.U32(3U), None, @lib.U64(8UL))
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
    ),
  )
  let body_for = fn(load : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_mul(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(0),
        load,
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_mul(),
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx,
      ]),
    )
    .with_mem_sec(
      @lib.MemSec::new([
        @lib.MemType::new(@lib.Limits::i32(1U, Some(1U)), shared=true),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        body_for(@lib.Instruction::i64_atomic_load(memarg64)),
        body_for(@lib.Instruction::i32_atomic_load8_u(memarg8)),
        body_for(@lib.Instruction::i32_atomic_load16_u(memarg16)),
        body_for(@lib.Instruction::i64_atomic_load8_u(memarg8)),
        body_for(@lib.Instruction::i64_atomic_load16_u(memarg16)),
        body_for(@lib.Instruction::i64_atomic_load32_u(memarg32)),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        @debug.assert_eq(locals, @lib.Locals::from_types([]))
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 0)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse defers local-only reuse across atomic rmw variants" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let memarg8 = @lib.MemArg::new(@lib.U32(0U), None, @lib.U64(0UL))
  let memarg16 = @lib.MemArg::new(@lib.U32(1U), None, @lib.U64(2UL))
  let memarg32 = @lib.MemArg::new(@lib.U32(2U), None, @lib.U64(4UL))
  let memarg64 = @lib.MemArg::new(@lib.U32(3U), None, @lib.U64(8UL))
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
    ),
  )
  let i32_body_for = fn(op : @lib.AtomicRmwOp, memarg : @lib.MemArg) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_xor(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(0),
        @lib.Instruction::i32_const(1),
        @lib.Instruction::atomic_rmw(op, memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_xor(),
        @lib.Instruction::drop(),
      ]),
    )
  }
  let i64_body_for = fn(op : @lib.AtomicRmwOp, memarg : @lib.MemArg) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_xor(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(0),
        @lib.Instruction::i64_const(1L),
        @lib.Instruction::atomic_rmw(op, memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_xor(),
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx, func_type_idx,
      ]),
    )
    .with_mem_sec(
      @lib.MemSec::new([
        @lib.MemType::new(@lib.Limits::i32(1U, Some(1U)), shared=true),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        i64_body_for(@lib.AtomicRmwOp::i64_sub(), memarg64),
        i32_body_for(@lib.AtomicRmwOp::i32_8_sub_u(), memarg8),
        i32_body_for(@lib.AtomicRmwOp::i32_16_and_u(), memarg16),
        i64_body_for(@lib.AtomicRmwOp::i64_8_and_u(), memarg8),
        i64_body_for(@lib.AtomicRmwOp::i64_16_or_u(), memarg16),
        i64_body_for(@lib.AtomicRmwOp::i64_32_or_u(), memarg32),
        i32_body_for(@lib.AtomicRmwOp::i32_xor(), memarg32),
        i64_body_for(@lib.AtomicRmwOp::i64_xor(), memarg64),
        i32_body_for(@lib.AtomicRmwOp::i32_8_xor_u(), memarg8),
        i64_body_for(@lib.AtomicRmwOp::i64_32_xor_u(), memarg32),
        i32_body_for(@lib.AtomicRmwOp::i32_xchg(), memarg32),
        i64_body_for(@lib.AtomicRmwOp::i64_32_xchg_u(), memarg32),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        @debug.assert_eq(locals, @lib.Locals::from_types([]))
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 0)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse defers local-only reuse across atomic store width variants" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let memarg8 = @lib.MemArg::new(@lib.U32(0U), None, @lib.U64(0UL))
  let memarg16 = @lib.MemArg::new(@lib.U32(1U), None, @lib.U64(2UL))
  let memarg64 = @lib.MemArg::new(@lib.U32(3U), None, @lib.U64(8UL))
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
    ),
  )
  let i32_store_body_for = fn(store : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_mul(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(0),
        @lib.Instruction::i32_const(7),
        store,
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_mul(),
        @lib.Instruction::drop(),
      ]),
    )
  }
  let i64_store_body_for = fn(store : @lib.Instruction) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_mul(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(0),
        @lib.Instruction::i64_const(7L),
        store,
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_mul(),
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
      ]),
    )
    .with_mem_sec(
      @lib.MemSec::new([
        @lib.MemType::new(@lib.Limits::i32(1U, Some(1U)), shared=true),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        i64_store_body_for(@lib.Instruction::i64_atomic_store(memarg64)),
        i32_store_body_for(@lib.Instruction::i32_atomic_store8(memarg8)),
        i32_store_body_for(@lib.Instruction::i32_atomic_store16(memarg16)),
        i64_store_body_for(@lib.Instruction::i64_atomic_store8(memarg8)),
        i64_store_body_for(@lib.Instruction::i64_atomic_store16(memarg16)),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        @debug.assert_eq(locals, @lib.Locals::from_types([]))
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 0)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse defers local-only reuse across atomic stores" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let memarg32 = @lib.MemArg::new(@lib.U32(2U), None, @lib.U64(0UL))
  let memarg32_narrow = @lib.MemArg::new(@lib.U32(2U), None, @lib.U64(4UL))
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx, func_type_idx]))
    .with_mem_sec(
      @lib.MemSec::new([
        @lib.MemType::new(@lib.Limits::i32(1U, Some(1U)), shared=true),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_mul(),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(7),
            @lib.Instruction::i32_atomic_store(memarg32),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_mul(),
            @lib.Instruction::drop(),
          ]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_mul(),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i64_const(7L),
            @lib.Instruction::i64_atomic_store32(memarg32_narrow),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_mul(),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        @debug.assert_eq(locals, @lib.Locals::from_types([]))
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 0)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse defers local-only reuse across atomic cmpxchg" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let memarg = @lib.MemArg::new(@lib.U32(2U), None, @lib.U64(0UL))
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_mem_sec(
      @lib.MemSec::new([
        @lib.MemType::new(@lib.Limits::i32(1U, Some(1U)), shared=true),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(1),
            @lib.Instruction::i32_const(2),
            @lib.Instruction::atomic_cmpxchg(
              @lib.AtomicCmpxchgOp::i32(),
              memarg,
            ),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(2U)), 0)
}

///|
test "local-cse defers local-only reuse across atomic cmpxchg width variants" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let memarg8 = @lib.MemArg::new(@lib.U32(0U), None, @lib.U64(0UL))
  let memarg16 = @lib.MemArg::new(@lib.U32(1U), None, @lib.U64(2UL))
  let memarg32 = @lib.MemArg::new(@lib.U32(2U), None, @lib.U64(4UL))
  let memarg64 = @lib.MemArg::new(@lib.U32(3U), None, @lib.U64(8UL))
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
    ),
  )
  let i32_body_for = fn(op : @lib.AtomicCmpxchgOp, memarg : @lib.MemArg) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(0),
        @lib.Instruction::i32_const(1),
        @lib.Instruction::i32_const(2),
        @lib.Instruction::atomic_cmpxchg(op, memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::drop(),
      ]),
    )
  }
  let i64_body_for = fn(op : @lib.AtomicCmpxchgOp, memarg : @lib.MemArg) {
    @lib.Func::new(
      @lib.Locals::from_types([]),
      @lib.Expr::new([
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::drop(),
        @lib.Instruction::i32_const(0),
        @lib.Instruction::i64_const(1L),
        @lib.Instruction::i64_const(2L),
        @lib.Instruction::atomic_cmpxchg(op, memarg),
        @lib.Instruction::drop(),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
        @lib.Instruction::i32_add(),
        @lib.Instruction::drop(),
      ]),
    )
  }
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(
      @lib.FuncSec::new([
        func_type_idx, func_type_idx, func_type_idx, func_type_idx, func_type_idx,
        func_type_idx,
      ]),
    )
    .with_mem_sec(
      @lib.MemSec::new([
        @lib.MemType::new(@lib.Limits::i32(1U, Some(1U)), shared=true),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        i64_body_for(@lib.AtomicCmpxchgOp::i64(), memarg64),
        i32_body_for(@lib.AtomicCmpxchgOp::i32_8_u(), memarg8),
        i32_body_for(@lib.AtomicCmpxchgOp::i32_16_u(), memarg16),
        i64_body_for(@lib.AtomicCmpxchgOp::i64_8_u(), memarg8),
        i64_body_for(@lib.AtomicCmpxchgOp::i64_16_u(), memarg16),
        i64_body_for(@lib.AtomicCmpxchgOp::i64_32_u(), memarg32),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  match optimized.code_sec {
    Some(@lib.CodeSec(funcs)) =>
      for func in funcs {
        let @lib.Func(locals, @lib.Expr(instrs)) = func
        @debug.assert_eq(locals, @lib.Locals::from_types([]))
        @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 0)
      }
    None => fail("expected code section")
  }
}

///|
test "local-cse defers local-only reuse across atomic wait notify and fence" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let memarg32 = @lib.MemArg::new(@lib.U32(2U), None, @lib.U64(0UL))
  let memarg64 = @lib.MemArg::new(@lib.U32(3U), None, @lib.U64(0UL))
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], []),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_mem_sec(
      @lib.MemSec::new([
        @lib.MemType::new(@lib.Limits::i32(1U, Some(1U)), shared=true),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(1),
            @lib.Instruction::memory_atomic_notify(memarg32),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i64_const(0L),
            @lib.Instruction::memory_atomic_wait32(memarg32),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i64_const(0L),
            @lib.Instruction::i64_const(0L),
            @lib.Instruction::memory_atomic_wait64(memarg64),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
            @lib.Instruction::atomic_fence(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(2U)), 0)
}

///|
test "local-cse defers local-only reuse across struct atomic get" {
  let input =
    #| (module
    #|   (type $box (sub (struct (field i32))))
    #|   (global $g (mut (ref null $box)) (ref.null $box))
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (drop (struct.atomic.get acq_rel $box 0 (global.get $g)))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(2U)), 0)
}

///|
test "local-cse reuses local-only expression across memory-fill" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (memory.fill (i32.const 0) (i32.const 7) (i32.const 1))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses local-only expression across memory-init" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (data "abcd")
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (memory.init 0 (i32.const 0) (i32.const 0) (i32.const 1))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses local-only expression across memory-grow" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (drop (memory.grow (i32.const 1)))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse does not reuse memory-size expression across memory-grow" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (func
    #|     (drop (i32.add (memory.size) (i32.const 1)))
    #|     (drop (memory.grow (i32.const 1)))
    #|     (drop (i32.add (memory.size) (i32.const 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(0U)), 0)
  @debug.assert_eq(lcse_test_count_local_get(instrs, @lib.LocalIdx::new(0U)), 0)
}

///|
test "local-cse reuses local-only expression across memory-size" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (drop (memory.size))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated memory-size root without intervening grow" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (func
    #|     (drop (i32.add (memory.size) (i32.const 1)))
    #|     (drop (i32.add (memory.size) (i32.const 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(0U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses memory-size expression across memory-copy" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (func
    #|     (drop (i32.add (memory.size) (i32.const 1)))
    #|     (memory.copy (i32.const 0) (i32.const 4) (i32.const 1))
    #|     (drop (i32.add (memory.size) (i32.const 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(0U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses memory-size expression across memory-fill" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (func
    #|     (drop (i32.add (memory.size) (i32.const 1)))
    #|     (memory.fill (i32.const 0) (i32.const 7) (i32.const 1))
    #|     (drop (i32.add (memory.size) (i32.const 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(0U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses memory-size expression across memory-init" {
  let input =
    #| (module
    #|   (memory 1)
    #|   (data "abcd")
    #|   (func
    #|     (drop (i32.add (memory.size) (i32.const 1)))
    #|     (memory.init 0 (i32.const 0) (i32.const 0) (i32.const 1))
    #|     (drop (i32.add (memory.size) (i32.const 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(0U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses local-only expression across table-copy" {
  let input =
    #| (module
    #|   (table 4 funcref)
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (table.copy 0 0 (i32.const 0) (i32.const 1) (i32.const 1))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses local-only expression across table-fill" {
  let input =
    #| (module
    #|   (table 4 funcref)
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (table.fill 0 (i32.const 0) (ref.null func) (i32.const 1))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses local-only expression across table-init" {
  let input =
    #| (module
    #|   (table 4 funcref)
    #|   (elem func)
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (table.init 0 0 (i32.const 0) (i32.const 0) (i32.const 0))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses local-only expression across table-set" {
  let input =
    #| (module
    #|   (table 4 funcref)
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (table.set 0 (i32.const 0) (ref.null func))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses local-only expression across table-get" {
  let input =
    #| (module
    #|   (table 4 funcref)
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (drop (table.get 0 (i32.const 0)))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse does not reuse table-get-dependent roots" {
  let input =
    #| (module
    #|   (table 4 funcref)
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (drop (ref.is_null (table.get 0 (i32.const 0))))
    #|     (drop (ref.is_null (table.get 0 (i32.const 0))))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse does not reuse table-get-dependent roots across table-set" {
  let input =
    #| (module
    #|   (table 4 funcref)
    #|   (func
    #|     (drop (ref.is_null (table.get 0 (i32.const 0))))
    #|     (table.set 0 (i32.const 0) (ref.null func))
    #|     (drop (ref.is_null (table.get 0 (i32.const 0))))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(0U)), 0)
  @debug.assert_eq(lcse_test_count_local_get(instrs, @lib.LocalIdx::new(0U)), 0)
}

///|
test "local-cse reuses local-only expression across table-grow" {
  let input =
    #| (module
    #|   (table 4 funcref)
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (drop (table.grow 0 (ref.null func) (i32.const 1)))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse does not reuse repeated table-grow roots" {
  let input =
    #| (module
    #|   (table 4 funcref)
    #|   (func
    #|     (drop (table.grow 0 (ref.null func) (i32.const 1)))
    #|     (drop (table.grow 0 (ref.null func) (i32.const 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(0U)), 0)
  @debug.assert_eq(lcse_test_count_local_get(instrs, @lib.LocalIdx::new(0U)), 0)
}

///|
test "local-cse reuses local-only expression across table-size" {
  let input =
    #| (module
    #|   (table 4 funcref)
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (drop (table.size 0))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse does not reuse repeated table-size roots" {
  let input =
    #| (module
    #|   (table 4 funcref)
    #|   (func
    #|     (drop (i32.add (table.size 0) (i32.const 1)))
    #|     (drop (i32.add (table.size 0) (i32.const 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(0U)), 0)
  @debug.assert_eq(lcse_test_count_local_get(instrs, @lib.LocalIdx::new(0U)), 0)
}

///|
test "local-cse does not reuse table-size-dependent roots across table-grow" {
  let input =
    #| (module
    #|   (table 4 funcref)
    #|   (func
    #|     (drop (i32.add (table.size 0) (i32.const 1)))
    #|     (drop (table.grow 0 (ref.null func) (i32.const 1)))
    #|     (drop (i32.add (table.size 0) (i32.const 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(0U)), 0)
  @debug.assert_eq(lcse_test_count_local_get(instrs, @lib.LocalIdx::new(0U)), 0)
}

///|
test "local-cse reuses local-only expression across data-drop" {
  let input =
    #| (module
    #|   (data "abcd")
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (data.drop 0)
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses local-only expression across elem-drop" {
  let input =
    #| (module
    #|   (elem func)
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (elem.drop 0)
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses local-only expression across global-set" {
  let input =
    #| (module
    #|   (global $g (mut i32) (i32.const 0))
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (global.set $g (i32.const 7))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse does not reuse global-dependent expression across global-set" {
  let input =
    #| (module
    #|   (global $g (mut i32) (i32.const 0))
    #|   (func
    #|     (drop (i32.add (global.get $g) (i32.const 1)))
    #|     (global.set $g (i32.const 7))
    #|     (drop (i32.add (global.get $g) (i32.const 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(0U)), 0)
  @debug.assert_eq(lcse_test_count_local_get(instrs, @lib.LocalIdx::new(0U)), 0)
}

///|
test "local-cse leaves repeated tiny global.get roots unmaterialized" {
  let input =
    #| (module
    #|   (global $g i32 (i32.const 7))
    #|   (func
    #|     (drop (global.get $g))
    #|     (drop (global.get $g))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(
    lcse_test_count_global_get(instrs, @lib.GlobalIdx::new(0U)),
    2,
  )
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(0U)), 0)
}

///|
test "local-cse reuses local-only expression across ref-eq" {
  let input =
    #| (module
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (drop (ref.eq (ref.null eq) (ref.null eq)))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses repeated ref-eq roots" {
  let input =
    #| (module
    #|   (func
    #|     (drop (ref.eq (ref.null eq) (ref.null eq)))
    #|     (drop (ref.eq (ref.null eq) (ref.null eq)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(0U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse does not reuse repeated struct-new roots" {
  let input =
    #| (module
    #|   (type $box (struct (field i32)))
    #|   (func
    #|     (drop (struct.new $box (i32.const 1)))
    #|     (drop (struct.new $box (i32.const 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(0U)), 0)
}

///|
test "local-cse does not reuse repeated struct-new-default roots" {
  let input =
    #| (module
    #|   (type $box (struct (field i32)))
    #|   (func
    #|     (drop (struct.new_default $box))
    #|     (drop (struct.new_default $box))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(0U)), 0)
}

///|
test "local-cse reuses local-only expression across struct-set" {
  let struct_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let struct_ref = @lib.ValType::ref_null(@lib.HeapType::new(struct_type_idx))
  let struct_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::struct_([
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ]),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func(
        [@lib.ValType::i32(), @lib.ValType::i32(), struct_ref],
        [],
      ),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([struct_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::i32_const(7),
            @lib.Instruction::struct_set(struct_type_idx, @lib.U32::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(3U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses local-only expression across array-set" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let array_ref = @lib.ValType::ref_null(@lib.HeapType::new(array_type_idx))
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func(
        [@lib.ValType::i32(), @lib.ValType::i32(), array_ref],
        [],
      ),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(7),
            @lib.Instruction::array_set(array_type_idx),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(3U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses local-only expression across array-fill" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let array_ref = @lib.ValType::ref_null(@lib.HeapType::new(array_type_idx))
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func(
        [@lib.ValType::i32(), @lib.ValType::i32(), array_ref],
        [],
      ),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(7),
            @lib.Instruction::i32_const(1),
            @lib.Instruction::array_fill(array_type_idx),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(3U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses local-only expression across array-copy" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let array_ref = @lib.ValType::ref_null(@lib.HeapType::new(array_type_idx))
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func(
        [@lib.ValType::i32(), @lib.ValType::i32(), array_ref, array_ref],
        [],
      ),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(1),
            @lib.Instruction::array_copy(array_type_idx, array_type_idx),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(4U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses local-only expression across array-init-data" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let data_idx = @lib.DataIdx::new(0U)
  let array_ref = @lib.ValType::ref_null(@lib.HeapType::new(array_type_idx))
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::pack_type(@lib.PackType::i8()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func(
        [@lib.ValType::i32(), @lib.ValType::i32(), array_ref],
        [],
      ),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32::new(1U)))
    .with_data_sec(
      @lib.DataSec::new([@lib.Data::new(@lib.DataMode::passive(), b"abcd")]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(1),
            @lib.Instruction::array_init_data(array_type_idx, data_idx),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(3U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses local-only expression across array-init-elem" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let dummy_func_type_idx = @lib.TypeIdx::new(1U)
  let func_type_idx = @lib.TypeIdx::new(2U)
  let elem_idx = @lib.ElemIdx::new(0U)
  let array_ref = @lib.ValType::ref_null(@lib.HeapType::new(array_type_idx))
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::funcref()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let dummy_func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func(
        [@lib.ValType::i32(), @lib.ValType::i32(), array_ref],
        [],
      ),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, dummy_func_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([dummy_func_type_idx, func_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::passive(),
          @lib.ElemKind::typed_exprs(
            @lib.RefType::abs(@lib.AbsHeapType::func()),
            [
              @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(0U))]),
            ],
          ),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::from_types([]), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(1),
            @lib.Instruction::array_init_elem(array_type_idx, elem_idx),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_defined_func(
    optimized, 1,
  )
  let temp = @lib.LocalIdx::new(3U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse does not reuse repeated array-new-default roots" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::const_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(2),
            @lib.Instruction::array_new_default(array_type_idx),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(2),
            @lib.Instruction::array_new_default(array_type_idx),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_array_new_default(instrs, array_type_idx), 2)
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(0U)), 0)
}

///|
test "local-cse does not reuse repeated array-new-fixed roots" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::const_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::i32_const(2),
            @lib.Instruction::array_new_fixed(array_type_idx, @lib.U32::new(2U)),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(1),
            @lib.Instruction::i32_const(2),
            @lib.Instruction::array_new_fixed(array_type_idx, @lib.U32::new(2U)),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_array_new_fixed(instrs, array_type_idx), 2)
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(0U)), 0)
}

///|
test "local-cse does not reuse repeated array-new-data roots" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let data_idx = @lib.DataIdx::new(0U)
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::pack_type(@lib.PackType::i8()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_data_cnt_sec(@lib.DataCntSec::new(@lib.U32::new(1U)))
    .with_data_sec(
      @lib.DataSec::new([@lib.Data::new(@lib.DataMode::passive(), b"abcd")]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(2),
            @lib.Instruction::array_new_data(array_type_idx, data_idx),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(2),
            @lib.Instruction::array_new_data(array_type_idx, data_idx),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(
    lcse_test_count_array_new_data(instrs, array_type_idx, data_idx),
    2,
  )
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(0U)), 0)
}

///|
test "local-cse does not reuse repeated array-new-elem roots" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let elem_idx = @lib.ElemIdx::new(0U)
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::funcref()),
          @lib.Mut::var_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx, func_type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::passive(),
          @lib.ElemKind::typed_exprs(
            @lib.RefType::abs(@lib.AbsHeapType::func()),
            [
              @lib.Expr::new([@lib.Instruction::ref_func(@lib.FuncIdx::new(0U))]),
            ],
          ),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::from_types([]), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(1),
            @lib.Instruction::array_new_elem(array_type_idx, elem_idx),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(0),
            @lib.Instruction::i32_const(1),
            @lib.Instruction::array_new_elem(array_type_idx, elem_idx),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_defined_func(
    optimized, 1,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(
    lcse_test_count_array_new_elem(instrs, array_type_idx, elem_idx),
    2,
  )
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(0U)), 0)
}

///|
test "local-cse does not reuse repeated array-new roots" {
  let array_type_idx = @lib.TypeIdx::new(0U)
  let func_type_idx = @lib.TypeIdx::new(1U)
  let array_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::array(
        @lib.FieldType::new(
          @lib.StorageType::val_type(@lib.ValType::i32()),
          @lib.Mut::const_(),
        ),
      ),
    ),
  )
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([array_type, func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::i32_const(1),
            @lib.Instruction::i32_const(2),
            @lib.Instruction::array_new(array_type_idx),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(1),
            @lib.Instruction::i32_const(2),
            @lib.Instruction::array_new(array_type_idx),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_array_new(instrs, array_type_idx), 2)
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(0U)), 0)
}

///|
test "local-cse reuses local-only expression across ordinary direct call" {
  let input =
    #| (module
    #|   (func $ordinary)
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (call $ordinary)
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_defined_func(
    optimized, 1,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse does not reuse global-dependent expression across ordinary direct call" {
  let input =
    #| (module
    #|   (global $g (mut i32) (i32.const 0))
    #|   (func $ordinary)
    #|   (func
    #|     (drop (i32.add (global.get $g) (i32.const 1)))
    #|     (call $ordinary)
    #|     (drop (i32.add (global.get $g) (i32.const 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_defined_func(
    optimized, 1,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_any_local_tee(instrs), 0)
}

///|
test "local-cse reuses annotated idempotent direct calls" {
  let input =
    #| (module
    #|   (@binaryen.idempotent)
    #|   (func $idempotent (param i32) (result i32)
    #|     (local.get 0))
    #|   (func (param i32)
    #|     (drop (call $idempotent (local.get 0)))
    #|     (drop (call $idempotent (local.get 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_defined_func(
    optimized, 1,
  )
  let temp = @lib.LocalIdx::new(1U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse does not reuse ordinary direct calls" {
  let input =
    #| (module
    #|   (func $ordinary (param i32) (result i32)
    #|     (local.get 0))
    #|   (func (param i32)
    #|     (drop (call $ordinary (local.get 0)))
    #|     (drop (call $ordinary (local.get 0)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_defined_func(
    optimized, 1,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(1U)), 0)
}

///|
test "local-cse conservatively clears local-only expression across call-indirect" {
  let input =
    #| (module
    #|   (type $t (func))
    #|   (table 1 funcref)
    #|   (elem (i32.const 0) $target)
    #|   (func $target)
    #|   (func (param i32 i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (call_indirect (type $t) (local.get 2))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_defined_func(
    optimized, 1,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(3U)), 0)
}

///|
test "local-cse does not reuse call-indirect roots" {
  let input =
    #| (module
    #|   (type $t (func (param i32) (result i32)))
    #|   (table 1 funcref)
    #|   (func $target (type $t)
    #|     (local.get 0))
    #|   (elem (i32.const 0) $target)
    #|   (func (param i32 i32)
    #|     (drop (call_indirect (type $t) (local.get 0) (local.get 1)))
    #|     (drop (call_indirect (type $t) (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_defined_func(
    optimized, 1,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(2U)), 0)
}

///|
test "local-cse reuses expression across return-call continuation" {
  let input =
    #| (module
    #|   (type $t (func (param i32) (result i32)))
    #|   (func $target (type $t)
    #|     (local.get 0))
    #|   (func (param i32 i32) (result i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (return_call $target (local.get 0))
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (i32.const 0)))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_defined_func(
    optimized, 1,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses expression across return-call-indirect continuation" {
  let input =
    #| (module
    #|   (type $t (func (param i32) (result i32)))
    #|   (table 1 funcref)
    #|   (func $target (type $t)
    #|     (local.get 0))
    #|   (elem (i32.const 0) $target)
    #|   (func (param i32 i32 i32) (result i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (return_call_indirect (type $t) (local.get 0) (local.get 2))
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (i32.const 0)))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_defined_func(
    optimized, 1,
  )
  let temp = @lib.LocalIdx::new(3U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses expression across return-call-ref continuation" {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let caller_type_idx = @lib.TypeIdx::new(1U)
  let callee_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let caller_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32(), @lib.ValType::i32()], [
        @lib.ValType::i32(),
      ]),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([callee_type, caller_type]))
    .with_func_sec(@lib.FuncSec::new([callee_type_idx, caller_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::return_call_ref(callee_type_idx),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
            @lib.Instruction::i32_const(0),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_defined_func(
    optimized, 1,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses expression across br-on-null continuation" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func(
        [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::externref()],
        [],
      ),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::void_(),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::drop(),
              ]),
            ),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(3U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses expression across br-on-cast continuation" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func(
        [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::anyref()],
        [],
      ),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::i31ref()),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_cast(
                  @lib.LabelIdx::new(0U),
                  true,
                  @lib.HeapType::abs(@lib.AbsHeapType::any()),
                  false,
                  @lib.HeapType::abs(@lib.AbsHeapType::i31()),
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::drop(),
                @lib.Instruction::i32_const(0),
                @lib.Instruction::ref_i31(),
              ]),
            ),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(3U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses expression across br-on-cast-fail continuation" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func(
        [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::anyref()],
        [],
      ),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::anyref()),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_cast_fail(
                  @lib.LabelIdx::new(0U),
                  true,
                  @lib.HeapType::abs(@lib.AbsHeapType::any()),
                  false,
                  @lib.HeapType::abs(@lib.AbsHeapType::i31()),
                ),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(
                  @lib.HeapType::abs(@lib.AbsHeapType::any()),
                ),
              ]),
            ),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(3U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses expression across br-on-non-null continuation" {
  let func_type_idx = @lib.TypeIdx::new(0U)
  let func_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func(
        [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::externref()],
        [],
      ),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([func_type]))
    .with_func_sec(@lib.FuncSec::new([func_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::block(
              @lib.BlockType::val_type(@lib.ValType::externref()),
              @lib.Expr::new([
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::drop(),
                @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
                @lib.Instruction::br_on_non_null(@lib.LabelIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
                @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
                @lib.Instruction::i32_add(),
                @lib.Instruction::drop(),
                @lib.Instruction::ref_null(
                  @lib.HeapType::abs(@lib.AbsHeapType::extern_()),
                ),
              ]),
            ),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(3U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse conservatively clears local-only expression across call-ref" {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let caller_type_idx = @lib.TypeIdx::new(1U)
  let callee_ref = @lib.ValType::ref_type(
    @lib.RefType::new(false, @lib.HeapType::new(callee_type_idx), exact=true),
  )
  let callee_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([], [])),
  )
  let caller_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func(
        [@lib.ValType::i32(), @lib.ValType::i32(), callee_ref],
        [],
      ),
    ),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([callee_type, caller_type]))
    .with_func_sec(@lib.FuncSec::new([callee_type_idx, caller_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::from_types([]), @lib.Expr::new([])),
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
            @lib.Instruction::call_ref(callee_type_idx),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
            @lib.Instruction::i32_add(),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_defined_func(
    optimized, 1,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(3U)), 0)
}

///|
test "local-cse does not reuse call-ref roots" {
  let callee_type_idx = @lib.TypeIdx::new(0U)
  let caller_type_idx = @lib.TypeIdx::new(1U)
  let callee_type = @lib.RecType::new(
    @lib.SubType::comp_type(
      @lib.CompType::func([@lib.ValType::i32()], [@lib.ValType::i32()]),
    ),
  )
  let caller_type = @lib.RecType::new(
    @lib.SubType::comp_type(@lib.CompType::func([@lib.ValType::i32()], [])),
  )
  let input = @lib.Module::new()
    .with_type_sec(@lib.TypeSec::new([callee_type, caller_type]))
    .with_func_sec(@lib.FuncSec::new([callee_type_idx, caller_type_idx]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([@lib.Instruction::local_get(@lib.LocalIdx::new(0U))]),
        ),
        @lib.Func::new(
          @lib.Locals::from_types([]),
          @lib.Expr::new([
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::call_ref(callee_type_idx),
            @lib.Instruction::drop(),
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
            @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
            @lib.Instruction::call_ref(callee_type_idx),
            @lib.Instruction::drop(),
          ]),
        ),
      ]),
    )
  let optimized = local_cse_run_module_pass(input)
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_defined_func(
    optimized, 1,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(1U)), 0)
}

///|
test "local-cse clears the reuse window across writes to read locals" {
  let input =
    #| (module
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (local.set 0 (i32.const 7))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  assert_false(
    instrs.contains(@lib.Instruction::local_tee(@lib.LocalIdx::new(2U))),
  )
}

///|
test "local-cse reuses expression across unrelated local-set" {
  let input =
    #| (module
    #|   (func (param i32 i32) (local i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (local.set 2 (i32.const 7))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(3U)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses expression across unrelated local-tee" {
  let input =
    #| (module
    #|   (func (param i32 i32) (local i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (drop (local.tee 2 (i32.const 7)))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(3U)
  @debug.assert_eq(
    locals,
    @lib.Locals::from_types([@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses before-if expression in then arm" {
  let input =
    #| (module
    #|   (func (param i32 i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (if (local.get 2)
    #|       (then
    #|         (drop (i32.add (local.get 0) (local.get 1)))))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(3U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses before-block expression in straight-line block" {
  let input =
    #| (module
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (block $named
    #|       (drop (i32.add (local.get 0) (local.get 1))))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse reuses before-try-table expression in try body" {
  let input =
    #| (module
    #|   (func (param i32 i32)
    #|     (block $exit
    #|       (drop (i32.add (local.get 0) (local.get 1)))
    #|       (try_table (catch_all $exit)
    #|         (drop (i32.add (local.get 0) (local.get 1)))))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(2U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse clears try-table body reuse at unreachable" {
  let input =
    #| (module
    #|   (func (param i32 i32)
    #|     (block $exit
    #|       (drop (i32.add (local.get 0) (local.get 1)))
    #|       (try_table (catch_all $exit)
    #|         (unreachable)
    #|         (drop (i32.add (local.get 0) (local.get 1)))))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(2U)), 0)
}

///|
test "local-cse does not reuse before-loop expression in loop body" {
  let input =
    #| (module
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (loop
    #|       (drop (i32.add (local.get 0) (local.get 1))))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(2U)), 0)
}

///|
test "local-cse does not reuse expression across br-table boundary" {
  let input =
    #| (module
    #|   (func (param i32 i32 i32)
    #|     (block $exit
    #|       (drop (i32.add (local.get 0) (local.get 1)))
    #|       (local.get 2)
    #|       (br_table $exit $exit)
    #|       (drop (i32.add (local.get 0) (local.get 1))))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(3U)), 0)
}

///|
test "local-cse does not reuse expression across br boundary" {
  let input =
    #| (module
    #|   (func (param i32 i32)
    #|     (block $exit
    #|       (drop (i32.add (local.get 0) (local.get 1)))
    #|       (br $exit)
    #|       (drop (i32.add (local.get 0) (local.get 1))))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(2U)), 0)
}

///|
test "local-cse does not reuse expression across unreachable boundary" {
  let input =
    #| (module
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (unreachable)
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(2U)), 0)
}

///|
test "local-cse removes dropped unreachable debris before hard unreachable" {
  let input =
    #| (module
    #|   (func
    #|     (drop (unreachable))
    #|     (unreachable)))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_drop(instrs), 0)
  @debug.assert_eq(lcse_test_count_unreachable(instrs), 1)
}

///|
test "local-cse removes nested dropped unreachable debris before hard unreachable" {
  let input =
    #| (module
    #|   (func
    #|     (drop (drop (unreachable)))
    #|     (unreachable)))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_drop(instrs), 0)
  @debug.assert_eq(lcse_test_count_unreachable(instrs), 1)
}

///|
test "local-cse removes dropped unreachable block debris before hard unreachable" {
  let input =
    #| (module
    #|   (func (result v128)
    #|     (block (result f64)
    #|       (drop
    #|         (i32x4.trunc_sat_f64x2_s_zero
    #|           (v128.const i32x4 0x8477c514 0x9702b3f3 0x11fe0a74 0xee94920a)))
    #|       (unreachable)
    #|       (unreachable))
    #|     (unreachable)))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_drop(instrs), 1)
  @debug.assert_eq(lcse_test_count_unreachable(instrs), 1)
}

///|
test "local-cse removes valueless dropped unreachable block debris before hard unreachable" {
  let input =
    #| (module
    #|   (func
    #|     (block (result f64)
    #|       (unreachable)
    #|       (unreachable))
    #|     (unreachable)))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_drop(instrs), 0)
  @debug.assert_eq(lcse_test_count_unreachable(instrs), 1)
}

///|
test "local-cse inlines branchless void block debris before hard unreachable" {
  let input =
    #| (module
    #|   (func
    #|     (block
    #|       (nop))
    #|     (unreachable)))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_block(instrs), 0)
  @debug.assert_eq(lcse_test_count_unreachable(instrs), 1)
}

///|
test "local-cse does not reuse expression across return boundary" {
  let input =
    #| (module
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (return)
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(2U)), 0)
}

///|
test "local-cse reuses expression across throw-ref continuation" {
  let input =
    #| (module
    #|   (func (param i32 i32 exnref)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (throw_ref (local.get 2))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  let temp = @lib.LocalIdx::new(3U)
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, temp), 1)
  @debug.assert_eq(lcse_test_count_local_get(instrs, temp), 1)
}

///|
test "local-cse does not reuse expression across throw boundary" {
  let input =
    #| (module
    #|   (tag $e)
    #|   (func (param i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (throw $e)
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(2U)), 0)
}

///|
test "local-cse does not reuse before-if expression after if" {
  let input =
    #| (module
    #|   (func (param i32 i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (if (local.get 2)
    #|       (then (drop (i32.const 1))))
    #|     (drop (i32.add (local.get 0) (local.get 1)))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(3U)), 0)
}

///|
test "local-cse does not reuse before-if expression in else arm" {
  let input =
    #| (module
    #|   (func (param i32 i32 i32)
    #|     (drop (i32.add (local.get 0) (local.get 1)))
    #|     (if (local.get 2)
    #|       (then (drop (i32.const 1)))
    #|       (else
    #|         (drop (i32.add (local.get 0) (local.get 1)))))))
    #|
  let optimized = match pass_test_run_pipeline(input, ["local-cse"]) {
    Ok(mod_) => mod_
    Err(err) => fail("expected local-cse pipeline success, got \{err}")
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = lcse_test_first_defined_func(
    optimized,
  )
  @debug.assert_eq(locals, @lib.Locals::from_types([]))
  @debug.assert_eq(lcse_test_count_local_tee(instrs, @lib.LocalIdx::new(3U)), 0)
}
