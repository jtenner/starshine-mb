///|
fn gen_valid_tuple_alias_test_profile() -> GenValidProfile raise {
  match gen_valid_profile_by_name("tuple-optimization-alias-captures") {
    Ok(profile) => profile
    Err(message) => fail(message)
  }
}

///|
fn gen_valid_tuple_alias_test_writes(
  body : Array[Instruction],
  writes : Array[Int32],
) -> Unit {
  for instr in body {
    match instr {
      LocalSet(LocalIdx(index)) | LocalTee(LocalIdx(index)) =>
        writes[index.to_int()] += 1
      Block(_, Expr(nested)) | Loop(_, Expr(nested)) =>
        gen_valid_tuple_alias_test_writes(nested, writes)
      If(_, yes, no) => {
        gen_valid_tuple_alias_test_writes(yes, writes)
        match no {
          Some(nested) => gen_valid_tuple_alias_test_writes(nested, writes)
          None => ()
        }
      }
      _ => ()
    }
  }
}

///|
// The generated loop has no result-bearing branches. This bounded integer
// executor rejects every opcode outside the intended fixture surface.
fn gen_valid_tuple_alias_test_execute(
  func : Func,
  argument : Int32,
) -> Array[Int32] raise {
  let Func(body_locals, Expr(body)) = func
  let locals = Array::make(1 + body_locals.length(), 0)
  locals[0] = argument
  let stack : Array[Int32] = []
  let mut fuel = 512
  fn execute(instrs : Array[Instruction]) -> Int32? raise {
    for instr in instrs {
      fuel -= 1
      assert_true(
        fuel > 0,
        msg="tuple generator exceeded the bounded loop budget",
      )
      match instr {
        Nop => ()
        I32Const(I32(value)) => stack.push(value)
        LocalGet(LocalIdx(index)) => stack.push(locals[index.to_int()])
        LocalSet(LocalIdx(index)) =>
          locals[index.to_int()] = stack.pop().unwrap()
        LocalTee(LocalIdx(index)) =>
          locals[index.to_int()] = stack[stack.length() - 1]
        I32Eqz => stack.push(if stack.pop().unwrap() == 0 { 1 } else { 0 })
        I32Add | I32And | I32LtS => {
          let rhs = stack.pop().unwrap()
          let lhs = stack.pop().unwrap()
          stack.push(
            match instr {
              I32Add => lhs + rhs
              I32And => lhs & rhs
              _ => if lhs < rhs { 1 } else { 0 }
            },
          )
        }
        Block(_, Expr(nested)) => @debug.assert_eq(execute(nested), None)
        Loop(VoidBlockType, Expr(nested)) => {
          let mut again = true
          while again {
            match execute(nested) {
              Some(0) => ()
              Some(depth) => return Some(depth - 1)
              None => again = false
            }
          }
        }
        If(VoidBlockType, yes, no) => {
          let condition = stack.pop().unwrap()
          @debug.assert_eq(
            execute(if condition != 0 { yes } else { no.or([]) }),
            None,
          )
        }
        BrIf(LabelIdx(depth)) =>
          if stack.pop().unwrap() != 0 {
            return Some(depth.to_int())
          }
        _ => fail("unexpected tuple generator instruction: \{instr}")
      }
    }
    None
  }
  @debug.assert_eq(execute(body), None)
  @debug.assert_eq(stack.length(), 2)
  stack
}

///|
test "tuple alias capture profile is a replayable aggregate leaf" {
  let profile = gen_valid_tuple_alias_test_profile()
  @debug.assert_eq(
    gen_valid_profile_name(profile),
    "tuple-optimization-alias-captures",
  )
  assert_true(
    gen_valid_profile_names().contains("tuple-optimization-alias-captures"),
  )
  assert_true(!gen_valid_profile_is_composite(profile))
  assert_true(
    gen_valid_profile_members(TupleOptimizationAllProfile).any(fn(member) {
      member.profile == profile
    }),
  )
}

///|
test "tuple alias capture generation exposes zero and prior snapshots across repeated producers" {
  let profile = gen_valid_tuple_alias_test_profile()
  let config = GenValidConfig::for_profile(profile)
  for seed in [0x7770UL, 0x7771UL, 0x7772UL] {
    let generated = match gen_valid_module_result_from_seed(seed, config) {
      Ok(value) => value
      Err(failure) => fail(failure.validation_error_message)
    }
    assert_true(validate_module(generated.wasm_module).is_ok())
    @debug.assert_eq(
      generated.config_label,
      "tuple-optimization-alias-captures",
    )
    let replay = gen_valid_module_result_from_seed(seed, config).unwrap()
    @debug.assert_eq(generated.wasm_module, replay.wasm_module)
    @debug.assert_eq(
      gen_valid_tuple_optimization_trigger_profile_case_label(profile, seed),
      Some(
        match seed % 3UL {
          0UL => "tuple-optimization:alias-captures-prefix"
          1UL => "tuple-optimization:alias-captures-trailing"
          _ => "tuple-optimization:alias-captures-chain"
        },
      ),
    )
    let funcs = generated.wasm_module.code_sec.unwrap().0
    @debug.assert_eq(funcs.length(), 2)
    @debug.assert_eq(generated.wasm_module.export_sec.unwrap().0.length(), 2)
    let first = 11 + (seed & 31UL).to_int()
    let second = 100 + ((seed >> 5) & 31UL).to_int()
    assert_true(first != second)
    for argument in [0, 1, 2, 3, 4, -1, -4, -2147483648, 2147483647] {
      // Limit is (argument & 3) + 1, so every function runs 1..4 iterations.
      let last_iteration = argument & 3
      @debug.assert_eq(gen_valid_tuple_alias_test_execute(funcs[0], argument), [
        first, second,
      ])
      @debug.assert_eq(
        gen_valid_tuple_alias_test_execute(funcs[1], argument),
        if last_iteration == 0 {
          [0, 0]
        } else {
          [first + last_iteration - 1, second + last_iteration - 1]
        },
      )
    }
    for func in funcs {
      let Func(_, Expr(body)) = func
      let writes = Array::make(10, 0)
      gen_valid_tuple_alias_test_writes(body, writes)
      for local_id in [1, 2, 3, 4, 7, 8] {
        @debug.assert_eq(writes[local_id], 1)
      }
      for local_id in [5, 6] {
        @debug.assert_eq(
          writes[local_id],
          if seed % 3UL == 2UL {
            1
          } else {
            0
          },
        )
      }
      let loops = body.filter(fn(instr) { instr is Loop(_, _) })
      @debug.assert_eq(loops.length(), 1)
      let loop_body = match loops[0] {
        Loop(VoidBlockType, Expr(loop_body)) => loop_body
        _ => fail("expected a bounded void loop")
      }
      assert_true(loop_body[0] is Block(TypeIdxBlockType(TypeIdx(1U)), _))
      @debug.assert_eq(loop_body[1], Instruction::local_set(LocalIdx::new(2U)))
      @debug.assert_eq(loop_body[2], Instruction::local_set(LocalIdx::new(1U)))
      assert_true(
        loop_body.any(fn(instr) { instr is Block(ValTypeBlockType(_), _) }),
      )
    }
  }
}
