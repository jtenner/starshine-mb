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
