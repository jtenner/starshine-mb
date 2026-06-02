///|
test "precompute raw tlsf prologue repair produces valid lowered function" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func (local i32 i32 i32 i32 i32)
    #|    memory.size
    #|    i32.const 177263
    #|    i32.const -16
    #|    i32.and
    #|    local.tee 0
    #|    i32.const 67107
    #|    i32.add
    #|    i32.const -65536
    #|    i32.and
    #|    i32.const 16
    #|    i32.shr_u
    #|    i32.lt_s
    #|    if (result i32)
    #|      local.get 3
    #|      local.get 4
    #|      i32.sub
    #|      memory.grow
    #|      i32.const 0
    #|      i32.lt_s
    #|    else
    #|      i32.const 0
    #|    end
    #|    if
    #|      unreachable
    #|    end
    #|    loop
    #|      i32.const 0
    #|      local.tee 1
    #|      i32.const 23
    #|      i32.lt_u
    #|      if
    #|        loop
    #|          i32.const 0
    #|          local.tee 2
    #|          i32.const 16
    #|          i32.lt_u
    #|          if
    #|            br 1
    #|          end
    #|        end
    #|        br 1
    #|      end
    #|    end))
    #|)
  let mod_ = pass_test_module_from_wat(source)
  let func = match mod_.code_sec {
    Some(@lib.CodeSec(defs)) => defs[0]
    None => fail("expected code section")
  }
  let (rewritten, changed, reason) = match precompute_run_raw_func(func, None) {
    Some(result) => result
    None => fail("expected raw tlsf rewrite result")
  }
  assert_true(changed, msg=reason)
  let candidate = mod_.with_code_sec(@lib.CodeSec::new([rewritten]))
  match @validate.validate_module(candidate) {
    Ok(_) => ()
    Err(err) =>
      fail("expected valid raw tlsf rewrite, got \{err}; mod=\{candidate}")
  }
}

///|
test "precompute rejects multi-root constant-if chosen regions" {
  let func = @ir.HotFunc::new()
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(2)),
      @ir.hot_build_const_i32(func, @lib.I32(3)),
    ]),
  )
  let else_region = @ir.hot_region_else_ref(func, if_id).unwrap()

  assert_false(
    precompute_constant_if_chosen_region_can_inline(func, else_region),
  )
}
