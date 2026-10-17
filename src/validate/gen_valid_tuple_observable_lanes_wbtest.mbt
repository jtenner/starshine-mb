///|
fn gen_valid_tuple_observable_check(
  profile : GenValidProfile,
  expected_i32 : Int32,
  expected_i64 : Int64,
) -> Unit raise {
  for seed in [1UL, 0x5eedUL, 0xffffffffffffffffUL] {
    let generated = match
      gen_valid_module_result_from_seed(
        seed,
        GenValidConfig::for_profile(profile),
      ) {
      Ok(value) => value
      Err(failure) => fail(failure.validation_error_message)
    }
    let mod_ = generated.wasm_module
    assert_true(validate_module(mod_) is Ok(_))
    let exports = match mod_.export_sec {
      Some(ExportSec(exports)) => exports
      None => fail("dedicated tuple lanes must have a callable export")
    }
    assert_true(
      exports.any(fn(export_) { export_.1 is FuncExternIdx(FuncIdx(0U)) }),
    )
    let TypeSec(types) = mod_.type_sec.unwrap()
    assert_eq(
      types[0].get_subtype(0U).unwrap().get_comptype(),
      CompType::func([], [ValType::i32(), ValType::i64()]),
    )
    let Func(locals, Expr(body)) = mod_.code_sec.unwrap().0[0]
    let values = Array::makei(locals.length(), fn(index) {
      if locals.get(index) == ValType::i64() {
        Instruction::i64_const(I64(0L))
      } else {
        Instruction::i32_const(I32(0))
      }
    })
    let stack : Array[Instruction] = []
    fn execute(instructions : Array[Instruction]) -> Unit raise {
      for instruction in instructions {
        match instruction {
          I32Const(_) | I64Const(_) => stack.push(instruction)
          Block(_, Expr(nested)) => execute(nested)
          LocalSet(LocalIdx(index)) =>
            values[index.to_int()] = stack.pop().unwrap()
          LocalTee(LocalIdx(index)) =>
            values[index.to_int()] = stack[stack.length() - 1]
          LocalGet(LocalIdx(index)) => stack.push(values[index.to_int()])
          Drop => ignore(stack.pop().unwrap())
          _ => fail("unexpected dedicated tuple opcode: \{instruction}")
        }
      }
    }
    execute(body)
    assert_eq(stack, [
      Instruction::i32_const(I32(expected_i32)),
      Instruction::i64_const(I64(expected_i64)),
    ])
    assert_true(gen_valid_test_to_module_local_write_count(mod_) >= 2)
    assert_true(gen_valid_test_to_module_has_typeidx_block(mod_))
  }
}

///|
test "tuple spill generator exports both observable lanes" {
  gen_valid_tuple_observable_check(TupleOptimizationSpillProfile, 7, 9L)
}

///|
test "tuple copy generator exports both observable lanes" {
  gen_valid_tuple_observable_check(TupleOptimizationCopyChainProfile, 11, 13L)
}

///|
test "tuple tee generator exports both observable lanes" {
  gen_valid_tuple_observable_check(TupleOptimizationTeeProfile, 17, 19L)
}
