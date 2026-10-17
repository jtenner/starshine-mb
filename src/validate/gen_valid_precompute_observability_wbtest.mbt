///|
fn gen_valid_precompute_observability_module(
  profile : GenValidProfile,
) -> Module raise {
  let generated = match
    gen_valid_module_result_from_seed(
      0x5eedUL,
      GenValidConfig::for_profile(profile),
    ) {
    Ok(value) => value.wasm_module
    Err(failure) => fail(failure.validation_error_message)
  }
  match validate_module(generated) {
    Ok(_) => ()
    Err(error) => fail(validation_error_message(error))
  }
  generated
}

///|
fn gen_valid_precompute_export_indices(mod_ : Module) -> Array[ExternIdx] {
  mod_.export_sec.unwrap().0.map(fn(export_) { export_.1 })
}

///|
fn gen_valid_precompute_exec_local_facts(
  body : Array[Instruction],
  funcs : Array[Func],
  locals : Array[UInt32],
  stack : Array[UInt32],
  checksum : Array[UInt32],
) -> Unit raise {
  for instr in body {
    match instr {
      I32Const(I32(value)) => stack.push(value.reinterpret_as_uint())
      LocalGet(LocalIdx(index)) =>
        stack.push(locals[index.reinterpret_as_int()])
      LocalSet(LocalIdx(index)) =>
        locals[index.reinterpret_as_int()] = stack.pop().unwrap()
      LocalTee(LocalIdx(index)) => {
        let value = stack.pop().unwrap()
        locals[index.reinterpret_as_int()] = value
        stack.push(value)
      }
      GlobalGet(GlobalIdx(0U)) => stack.push(checksum[0])
      GlobalSet(GlobalIdx(0U)) => checksum[0] = stack.pop().unwrap()
      I32Add => {
        let right = stack.pop().unwrap()
        let left = stack.pop().unwrap()
        stack.push(left + right)
      }
      I32Mul => {
        let right = stack.pop().unwrap()
        let left = stack.pop().unwrap()
        stack.push(left * right)
      }
      Drop => ignore(stack.pop().unwrap())
      If(_, yes, no) => {
        let condition = stack.pop().unwrap()
        gen_valid_precompute_exec_local_facts(
          if condition == 0U {
            no.unwrap_or([])
          } else {
            yes
          },
          funcs,
          locals,
          stack,
          checksum,
        )
      }
      Block(_, Expr(nested)) =>
        gen_valid_precompute_exec_local_facts(
          nested, funcs, locals, stack, checksum,
        )
      Call(FuncIdx(0U)) => {
        let argument = stack.pop().unwrap()
        let Func(_, Expr(observer)) = funcs[0]
        let observer_stack : Array[UInt32] = []
        gen_valid_precompute_exec_local_facts(
          observer,
          funcs,
          [argument],
          observer_stack,
          checksum,
        )
        assert_eq(observer_stack.length(), 0)
      }
      _ => abort("unexpected local-facts evaluator opcode: \{instr}")
    }
  }
}

///|
test "precompute fixed profiles export their bounded observable surface" {
  let profiles = [
    PrecomputeScalarProfile,
    PrecomputeScalarValueProfile,
    PrecomputeGcValueProfile,
    PrecomputeEffectfulValueProfile,
    PrecomputeControlProfile,
    PrecomputeGlobalProfile,
    PrecomputeDropCleanupProfile,
    PrecomputeEffectBoundaryProfile,
    PrecomputeGcAtomicBoundaryProfile,
    PrecomputeDirectPrefixWatchProfile,
    PrecomputePropagateLocalFactsProfile,
  ]
  for profile in profiles {
    let first = gen_valid_precompute_observability_module(profile)
    let second = gen_valid_precompute_observability_module(profile)
    assert_true(first.start_sec is None)
    assert_true(first.export_sec.unwrap().0.length() > 0)
    @debug.assert_eq(
      @binary.encode_module(first).unwrap(),
      @binary.encode_module(second).unwrap(),
    )
  }
  @debug.assert_eq(
    gen_valid_precompute_export_indices(
      gen_valid_precompute_observability_module(PrecomputeScalarProfile),
    ),
    [ExternIdx::func(FuncIdx::new(0U)), ExternIdx::global(GlobalIdx::new(0U))],
  )
  @debug.assert_eq(
    gen_valid_precompute_export_indices(
      gen_valid_precompute_observability_module(PrecomputeEffectfulValueProfile),
    ),
    [ExternIdx::func(FuncIdx::new(0U))],
  )
  @debug.assert_eq(
    gen_valid_precompute_export_indices(
      gen_valid_precompute_observability_module(PrecomputeControlProfile),
    ),
    [
      ExternIdx::func(FuncIdx::new(0U)),
      ExternIdx::func(FuncIdx::new(1U)),
      ExternIdx::global(GlobalIdx::new(0U)),
    ],
  )
  @debug.assert_eq(
    gen_valid_precompute_export_indices(
      gen_valid_precompute_observability_module(PrecomputeGlobalProfile),
    ),
    [
      ExternIdx::func(FuncIdx::new(0U)),
      ExternIdx::global(GlobalIdx::new(0U)),
      ExternIdx::global(GlobalIdx::new(1U)),
      ExternIdx::global(GlobalIdx::new(2U)),
      ExternIdx::global(GlobalIdx::new(3U)),
    ],
  )
  @debug.assert_eq(
    gen_valid_precompute_export_indices(
      gen_valid_precompute_observability_module(PrecomputeDropCleanupProfile),
    ),
    [ExternIdx::func(FuncIdx::new(0U)), ExternIdx::global(GlobalIdx::new(0U))],
  )
  @debug.assert_eq(
    gen_valid_precompute_export_indices(
      gen_valid_precompute_observability_module(PrecomputeEffectBoundaryProfile),
    ),
    [
      ExternIdx::func(FuncIdx::new(1U)),
      ExternIdx::mem(MemIdx::new(0U)),
      ExternIdx::global(GlobalIdx::new(0U)),
    ],
  )
  @debug.assert_eq(
    gen_valid_precompute_export_indices(
      gen_valid_precompute_observability_module(
        PrecomputeDirectPrefixWatchProfile,
      ),
    ),
    [ExternIdx::func(FuncIdx::new(0U))],
  )
}

///|
test "precompute fixed scalar leaves publish every folded result" {
  for
    profile in [
      PrecomputeScalarProfile,
      PrecomputeControlProfile,
      PrecomputeGlobalProfile,
      PrecomputeDropCleanupProfile,
    ] {
    let (checksum_idx, expected_sets) = match profile {
      PrecomputeScalarProfile => (0U, 5)
      PrecomputeControlProfile => (0U, 4)
      PrecomputeGlobalProfile => (3U, 3)
      PrecomputeDropCleanupProfile => (0U, 3)
      _ => abort("unexpected Precompute observability profile")
    }
    let mod_ = gen_valid_precompute_observability_module(profile)
    let Func(_, Expr(body)) = mod_.code_sec.unwrap().0[0]
    let pending : Array[Array[Instruction]] = [body]
    let mut sets = 0
    while !pending.is_empty() {
      for instr in pending.pop().unwrap() {
        match instr {
          GlobalSet(GlobalIdx(index)) if index == checksum_idx => sets += 1
          Block(_, Expr(nested)) => pending.push(nested)
          If(_, yes, no) => {
            pending.push(yes)
            if no is Some(nested) {
              pending.push(nested)
            }
          }
          _ => ()
        }
      }
    }
    assert_eq(
      sets,
      expected_sets,
      msg="observable checksum writes for \{gen_valid_profile_name(profile)}",
    )
  }
}

///|
test "precompute value profiles exclude unbounded GC and NaN-bit calls" {
  let scalar = gen_valid_precompute_observability_module(
    PrecomputeScalarValueProfile,
  )
  let scalar_indices = gen_valid_precompute_export_indices(scalar)
  @debug.assert_eq(scalar_indices, [
    ExternIdx::func(FuncIdx::new(0U)),
    ExternIdx::func(FuncIdx::new(1U)),
    ExternIdx::func(FuncIdx::new(2U)),
    ExternIdx::func(FuncIdx::new(3U)),
    ExternIdx::func(FuncIdx::new(4U)),
    ExternIdx::func(FuncIdx::new(6U)),
    ExternIdx::func(FuncIdx::new(8U)),
    ExternIdx::func(FuncIdx::new(9U)),
    ExternIdx::func(FuncIdx::new(10U)),
    ExternIdx::func(FuncIdx::new(11U)),
    ExternIdx::func(FuncIdx::new(12U)),
    ExternIdx::func(FuncIdx::new(13U)),
    ExternIdx::func(FuncIdx::new(14U)),
    ExternIdx::func(FuncIdx::new(15U)),
    ExternIdx::func(FuncIdx::new(16U)),
    ExternIdx::func(FuncIdx::new(17U)),
    ExternIdx::func(FuncIdx::new(24U)),
    ExternIdx::func(FuncIdx::new(25U)),
  ])
  for excluded in [5U, 7U, 18U, 19U, 20U, 21U, 22U, 23U] {
    assert_false(
      scalar_indices.contains(ExternIdx::func(FuncIdx::new(excluded))),
    )
  }

  let gc = gen_valid_precompute_observability_module(PrecomputeGcValueProfile)
  let gc_indices = gen_valid_precompute_export_indices(gc)
  @debug.assert_eq(gc_indices, [
    ExternIdx::func(FuncIdx::new(0U)),
    ExternIdx::func(FuncIdx::new(1U)),
    ExternIdx::func(FuncIdx::new(2U)),
    ExternIdx::func(FuncIdx::new(3U)),
    ExternIdx::func(FuncIdx::new(4U)),
    ExternIdx::func(FuncIdx::new(5U)),
    ExternIdx::func(FuncIdx::new(9U)),
  ])
  for excluded in [6U, 7U, 8U, 10U, 11U, 12U] {
    assert_false(gc_indices.contains(ExternIdx::func(FuncIdx::new(excluded))))
  }
  assert_eq(gc.code_sec.unwrap().0.length(), 13)
}

///|
test "precompute atomic profile calls the original body through a bounded wrapper" {
  let config = GenValidConfig::for_profile(PrecomputeGcAtomicBoundaryProfile)
  assert_true(config.max_type_defs >= 4)
  assert_true(config.max_defined_funcs >= 2)
  assert_true(config.features.allow_calls)
  let mod_ = gen_valid_precompute_observability_module(
    PrecomputeGcAtomicBoundaryProfile,
  )
  @debug.assert_eq(gen_valid_precompute_export_indices(mod_), [
    ExternIdx::func(FuncIdx::new(1U)),
  ])
  let Func(_, Expr(wrapper)) = mod_.code_sec.unwrap().0[1]
  @debug.assert_eq(wrapper, [
    Instruction::i32_const(I32(0)),
    Instruction::struct_new(TypeIdx::new(0U)),
    Instruction::call(FuncIdx::new(0U)),
  ])
}

///|
test "precompute local facts records every propagated value in an exported checksum" {
  let config = GenValidConfig::for_profile(PrecomputePropagateLocalFactsProfile)
  assert_true(config.max_globals >= 1)
  assert_true(config.features.allow_globals)
  let mod_ = gen_valid_precompute_observability_module(
    PrecomputePropagateLocalFactsProfile,
  )
  @debug.assert_eq(gen_valid_precompute_export_indices(mod_), [
    ExternIdx::func(FuncIdx::new(1U)),
    ExternIdx::global(GlobalIdx::new(0U)),
  ])
  let funcs = mod_.code_sec.unwrap().0
  let Func(_, Expr(observer)) = funcs[0]
  @debug.assert_eq(observer, [
    Instruction::global_get(GlobalIdx::new(0U)),
    Instruction::i32_const(I32(131)),
    Instruction::i32_mul(),
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::i32_add(),
    Instruction::global_set(GlobalIdx::new(0U)),
  ])
  let Func(_, Expr(trigger)) = funcs[1]
  assert_eq(
    trigger
    .filter(fn(instr) { instr == Instruction::call(FuncIdx::new(0U)) })
    .length(),
    7,
  )
  for
    (input, expected) in [
      (0, -1237189967),
      (1, -485029836),
      (-1, -485029838),
      (-2147483648, 1662453811),
      (2147483647, 1662453810),
    ] {
    let locals = Array::make(7, 0U)
    locals[0] = input.reinterpret_as_uint()
    let stack : Array[UInt32] = []
    let checksum = [0U]
    gen_valid_precompute_exec_local_facts(
      trigger, funcs, locals, stack, checksum,
    )
    assert_eq(stack.length(), 0)
    assert_eq(checksum[0].reinterpret_as_int(), expected)
  }
}
