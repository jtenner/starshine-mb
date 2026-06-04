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
