///|
test "hot lower keeps unreachable in exact cmd inner carrier shape" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32 i32 i32) (result i32) (local i32 i32 i32 i32 i32) (local.set 3 (block $block2 (result i32) (block $block1 (br $block2 (block (result i32) (block $block (if (i32.eq (local.get 0) (i32.const 1)) (then (local.set 4 (local.tee 5 (local.get 1))) (br $block)) (else (local.set 6 (local.tee 7 (local.get 2))) (br $block1)))) (local.get 4)))))) (local.get 3)))",
  )
  let lowered = hot_lower_func(fixture.hot_func)
  let pretty = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func(
              [@lib.ValType::i32(), @lib.ValType::i32(), @lib.ValType::i32()],
              [@lib.ValType::i32()],
            ),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(@lib.CodeSec::new([lowered]))
    .pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(pretty.contains("unreachable"), msg=pretty)
}

///|
test "hot lower live repro validates parent-exit payload carry shape" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32 i32) (result i32) (local i32) (block $outer (result i32) (block $exit (block $work (if (i32.eq (local.get 0) (i32.const 1)) (then (local.set 2 (local.get 1)) (br $work)) (else (local.set 2 (i32.const 9)) (br $exit))) unreachable) (br $outer (local.get 2))) (i32.const 0))))",
  )
  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates compare-shape split local.set carry" {
  let source =
    #|(module
    #|  (func (param i64) (result i32) (local i32 i32 i64 i32)
    #|    (local.set 1
    #|      (block $block24 (result i32)
    #|        (block $block23
    #|          (if
    #|            (i64.eq
    #|              (local.tee 3
    #|                (local.get 0))
    #|              (i64.const 4294967296))
    #|            (then
    #|              (drop
    #|                (i32.const 5))
    #|              (br $block23))
    #|            (else
    #|              (local.set 2
    #|                (local.tee 4
    #|                  (i32.wrap_i64
    #|                    (local.tee 3
    #|                      (local.get 3)))))
    #|              (br $block23)))
    #|          unreachable)
    #|        (local.get 2)))
    #|    (local.get 1)))
  let fixture = ir_test_build_hot_from_wat(source)
  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates typed loop carrier reloads backedge value" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32) (local i32)
    #|    i32.const 0
    #|    loop $loop (type $loop_t)
    #|      local.tee 1
    #|      local.get 0
    #|      i32.lt_s
    #|      if
    #|        local.get 1
    #|        i32.const 1
    #|        i32.add
    #|        br $loop
    #|      end
    #|      local.get 1
    #|      drop
    #|    end
    #|    i32.const 1)
    #|)
  let fixture = ir_test_build_hot_from_wat(source)
  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates repeated shared operand emission" {
  let fixture = ir_test_build_hot_from_wat(
    "(module (func (param i32 i32) (result i32) (i32.add (local.get 0) (local.get 1))))",
  )
  let add_id = hot_root_get(fixture.hot_func, 0)
  let lhs = hot_child_get(fixture.hot_func, add_id, 0)
  hot_child_set(fixture.hot_func, add_id, 1, lhs)
  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro validates value-if condition consumed before later drop" {
  let source =
    #|(module
    #|  (type $loop_t (func (param i32)))
    #|  (func (param i32) (result i32)
    #|    i32.const 0
    #|    loop $loop (type $loop_t)
    #|      local.tee 0
    #|      i32.const 0
    #|      i32.lt_s
    #|      if (result i32)
    #|        i32.const 1
    #|      else
    #|        local.get 0
    #|        i32.const 5
    #|        i32.ge_s
    #|      end
    #|      if
    #|        nop
    #|      end
    #|      local.get 0
    #|      drop
    #|      local.get 0
    #|      i32.const 1
    #|      i32.add
    #|      br $loop
    #|    end
    #|    i32.const 1)
    #|)
  let fixture = ir_test_build_hot_from_wat(source)
  let mut loop_id = -1
  for idx = 0; idx < hot_root_count(fixture.hot_func); idx = idx + 1 {
    let root_id = hot_root_get(fixture.hot_func, idx)
    match hot_node_get(fixture.hot_func, root_id).op {
      Loop => {
        loop_id = root_id
        break
      }
      _ => ()
    }
  }
  if loop_id < 0 {
    fail("expected fixture loop root")
  }
  let loop_body = hot_region_body_ref(fixture.hot_func, loop_id)
  let value_if = hot_region_get(fixture.hot_func, loop_body, 0)
  let inner_value_if = hot_child_get(fixture.hot_func, value_if, 0)
  let value_if_else = match
    hot_region_else_ref(fixture.hot_func, inner_value_if) {
    Some(region) => region
    None => fail("expected nested if with else")
  }
  let compare = hot_region_get(fixture.hot_func, value_if_else, 0)
  let shared_local_get = hot_child_get(fixture.hot_func, compare, 0)
  let drop_root = hot_region_get(fixture.hot_func, loop_body, 2)
  hot_child_set(fixture.hot_func, drop_root, 0, shared_local_get)
  let lowered = hot_lower_func(fixture.hot_func)
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}

///|
test "hot lower live repro keeps call result spills behind mixed-typed call operands" {
  let source =
    #|(module
    #|  (type $callee_t (func (param i32 i32 i32 i64 i32) (result i32)))
    #|  (import "env" "callee" (func $callee (type $callee_t)))
    #|  (memory 1)
    #|  (func (param i32 i32 i32 i64) (result i64) (local i32)
    #|    local.get 0
    #|    local.get 1
    #|    local.get 2
    #|    local.get 3
    #|    i32.const 1
    #|    call $callee
    #|    local.set 4
    #|    local.get 4
    #|    i64.load offset=8 align=1))
    #|)
  let fixture = ir_test_build_hot_from_wat(source)
  let lowered = hot_lower_func(fixture.hot_func)
  let @lib.Func(locals, body) = lowered
  @debug.assert_eq(locals, @lib.Locals::from_types([@lib.ValType::i32()]))
  @debug.assert_eq(
    body,
    @lib.Expr::new([
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(3U)),
      @lib.Instruction::i32_const(@lib.I32(1)),
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::local_set(@lib.LocalIdx::new(4U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(4U)),
      @lib.Instruction::i64_load(
        @lib.MemArg::new(@lib.U32(0), None, @lib.U64(8)),
      ),
    ]),
  )
  let next_code_sec = match fixture.mod_.code_sec {
    Some(@lib.CodeSec(defs)) => {
      let next_defs = defs.copy()
      next_defs[fixture.code_idx] = lowered
      @lib.CodeSec::new(next_defs)
    }
    None => fail("fixture missing code sec")
  }
  let out = fixture.mod_.with_code_sec(next_code_sec)
  match @validate.validate_module(out) {
    Ok(_) => ()
    Err(err) => fail(@validate.validation_error_message(err))
  }
}
