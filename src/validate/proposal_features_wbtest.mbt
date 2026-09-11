///|
fn proposal_test_function(
  params : Array[ValType],
  results : Array[ValType],
  body : Array[Instruction],
) -> Module {
  Module::new()
  .with_type_sec(
    TypeSec::new([
      RecType::new(SubType::comp_type(CompType::func(params, results))),
    ]),
  )
  .with_func_sec(FuncSec::new([TypeIdx::new(0U)]))
  .with_code_sec(CodeSec::new([Func::new(Locals::empty(), Expr::new(body))]))
}

///|
test "proposal feature policy keeps acquire release and relaxed atomics independent" {
  for
    entry in [
      (AtomicOrder::acq_rel(), AcquireReleaseAtomics, RelaxedAtomics),
      (AtomicOrder::relaxed(), RelaxedAtomics, AcquireReleaseAtomics),
    ] {
    let (order, required, unrelated) = entry
    let input = proposal_test_function([], [], [
      Instruction::atomic_fence(order~),
    ])
    @debug.assert_eq(module_proposal_features(input), [required])
    assert_true(validate_module(input, disabled_features=[unrelated]) is Ok(_))
    match validate_module(input, disabled_features=[required]) {
      Err(err) =>
        assert_true(
          validation_error_message(err).contains(
            proposal_feature_name(required),
          ),
        )
      Ok(_) => fail("disabled atomic order accepted")
    }
  }
  let ordinary = proposal_test_function([], [], [Instruction::atomic_fence()])
  assert_true(
    validate_module(ordinary, disabled_features=controlled_proposal_features())
    is Ok(_),
  )
}

///|
test "proposal feature policy checks waitqueue types initializers and multibyte arrays" {
  for
    entry in [
      (Binaryen132WaitqueueProfile, SharedEverything),
      (Binaryen132ArrayMemoryProfile, Multibyte),
    ] {
    let (profile, required) = entry
    let input = gen_valid_module_from_seed(
        4UL,
        GenValidConfig::for_profile(profile),
      ).unwrap().wasm_module
    assert_true(module_proposal_features(input).contains(required))
    assert_true(validate_module(input) is Ok(_))
    assert_true(validate_module(input, disabled_features=[required]) is Err(_))
  }
  let type_only = Module::new().with_type_sec(
    TypeSec::new([
      RecType::new(
        SubType::comp_type(CompType::func([waitqueue_test_ref(true, true)], [])),
      ),
    ]),
  )
  @debug.assert_eq(module_proposal_features(type_only), [SharedEverything])
  assert_true(
    validate_module(type_only, disabled_features=[SharedEverything]) is Err(_),
  )
}

///|
test "proposal feature inference includes the released relaxed dot add opcode" {
  let vector = ValType::v128()
  let input = proposal_test_function([vector, vector, vector], [vector], [
    Instruction::local_get(LocalIdx::new(0U)),
    Instruction::local_get(LocalIdx::new(1U)),
    Instruction::local_get(LocalIdx::new(2U)),
    Instruction::i32x4_relaxed_dot_i8x16i7x16_add_s(),
  ])
  @debug.assert_eq(module_proposal_features(input), [RelaxedSimd])
  assert_true(validate_module(input) is Ok(_))
  assert_true(validate_module(input, disabled_features=[RelaxedSimd]) is Err(_))
}
