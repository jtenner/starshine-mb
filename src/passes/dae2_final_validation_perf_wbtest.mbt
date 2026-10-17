///|
fn dae2_final_validation_bench(
  it : @bench.T,
  width : Int32,
  reference : Bool,
  named~ : Bool = false,
) -> Unit {
  let input = dae2_final_validation_fixture()
  let input = if named {
    input.with_name_sec(
      @lib.NameSec::new(
        type_names=Some(
          @lib.NameMap::new([
            @lib.NameAssoc::new(0U, @lib.Name::from_string("signature")),
            @lib.NameAssoc::new(1U, @lib.Name::from_string("duplicate")),
          ]),
        ),
      ),
    )
  } else {
    input
  }
  let body : Array[@lib.Instruction] = []
  for _ in 0..<width {
    body.push(@lib.Instruction::i32_const(@lib.I32(1)))
    body.push(@lib.Instruction::drop())
  }
  body.push(@lib.Instruction::i32_const(@lib.I32(7)))
  let input = input.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
      input.code_sec.unwrap().0[1],
    ]),
  )
  let saved = @binary.encode_module(input).unwrap()
  let expected = dae2_final_validation_reference(input).unwrap()
  let actual = dae2_finalize_candidate(input).unwrap()
  @validate.validate_module(actual).unwrap()
  if @binary.encode_module(actual).unwrap() !=
    @binary.encode_module(expected).unwrap() {
    abort("final validation changed cleaned module bytes")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        dae2_final_validation_reference(input)
      } else {
        dae2_finalize_candidate(input)
      },
    )
  })
  if @binary.encode_module(input).unwrap() != saved {
    abort("final validation mutated its source")
  }
}

///|
test "bench DAE2 final validation width=128 reference" (it : @bench.T) {
  dae2_final_validation_bench(it, 128, true)
}

///|
test "bench DAE2 final validation width=128 consolidated" (it : @bench.T) {
  dae2_final_validation_bench(it, 128, false)
}

///|
test "bench DAE2 final validation width=4096 reference" (it : @bench.T) {
  dae2_final_validation_bench(it, 4096, true)
}

///|
test "bench DAE2 final validation width=4096 consolidated" (it : @bench.T) {
  dae2_final_validation_bench(it, 4096, false)
}

///|
test "bench DAE2 final validation named width=128 reference" (it : @bench.T) {
  dae2_final_validation_bench(it, 128, true, named=true)
}

///|
test "bench DAE2 final validation named width=128 consolidated" (it : @bench.T) {
  dae2_final_validation_bench(it, 128, false, named=true)
}

///|
test "bench DAE2 final validation named width=4096 reference" (it : @bench.T) {
  dae2_final_validation_bench(it, 4096, true, named=true)
}

///|
test "bench DAE2 final validation named width=4096 consolidated" (it : @bench.T) {
  dae2_final_validation_bench(it, 4096, false, named=true)
}

///|
fn dae2_final_validation_live_types_fixture(count : Int32) -> @lib.Module {
  let types : Array[@lib.RecType] = []
  let indices : Array[@lib.TypeIdx] = []
  let funcs : Array[@lib.Func] = []
  for index in 0..<count {
    // All signatures are distinct and referenced, so neither cleanup applies.
    types.push(
      @lib.RecType::new(
        @lib.SubType::comp_type(
          @lib.CompType::func(Array::make(index, @lib.ValType::i32()), []),
        ),
      ),
    )
    indices.push(@lib.TypeIdx::new(index.to_uint()))
    funcs.push(@lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([])))
  }
  @lib.Module::new()
  .with_type_sec(@lib.TypeSec::new(types))
  .with_func_sec(@lib.FuncSec::new(indices))
  .with_code_sec(@lib.CodeSec::new(funcs))
}

///|
fn dae2_final_validation_live_types_bench(
  it : @bench.T,
  count : Int32,
  reference : Bool,
) -> Unit {
  let input = dae2_final_validation_live_types_fixture(count)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let expected = dae2_final_validation_reference(input).unwrap()
  let actual = dae2_finalize_candidate(input).unwrap()
  if !physical_equal(actual, input) || !physical_equal(expected, input) {
    abort("live signatures unexpectedly triggered type cleanup")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        dae2_final_validation_reference(input)
      } else {
        dae2_finalize_candidate(input)
      },
    )
  })
  if @binary.encode_module(input).unwrap() != saved {
    abort("no-cleanup final validation mutated its source")
  }
}

///|
test "bench DAE2 final validation live types=64 reference" (it : @bench.T) {
  dae2_final_validation_live_types_bench(it, 64, true)
}

///|
test "bench DAE2 final validation live types=64 consolidated" (it : @bench.T) {
  dae2_final_validation_live_types_bench(it, 64, false)
}

///|
test "bench DAE2 final validation live types=256 reference" (it : @bench.T) {
  dae2_final_validation_live_types_bench(it, 256, true)
}

///|
test "bench DAE2 final validation live types=256 consolidated" (it : @bench.T) {
  dae2_final_validation_live_types_bench(it, 256, false)
}

///|
fn dae2_final_validation_prune_only_bench(
  it : @bench.T,
  count : Int32,
  reference : Bool,
) -> Unit {
  let live = dae2_final_validation_live_types_fixture(count)
  let types = live.type_sec.unwrap().0.copy()
  // This unique, unused signature adds pruning without duplicate compaction.
  types.push(
    @lib.RecType::new(
      @lib.SubType::comp_type(
        @lib.CompType::func(Array::make(count, @lib.ValType::i32()), []),
      ),
    ),
  )
  let input = live.with_type_sec(@lib.TypeSec::new(types))
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let grouped = dae_prune_unused_simple_func_types(input, preserve_names=true)
  if grouped.type_sec.unwrap().0.length() != count ||
    dfe_cleanup_simple_type_encoding_candidate(grouped) is Some(_) {
    abort("prune-only fixture unexpectedly triggered duplicate compaction")
  }
  let expected = dae2_final_validation_reference(input).unwrap()
  let actual = dae2_finalize_candidate(input).unwrap()
  @validate.validate_module(actual).unwrap()
  if actual.type_sec.unwrap().0.length() != count ||
    actual.func_sec != input.func_sec ||
    actual.code_sec != input.code_sec ||
    @binary.encode_module(actual).unwrap() !=
    @binary.encode_module(expected).unwrap() {
    abort("prune-only final validation changed retained signatures or bodies")
  }
  if @binary.encode_module(input).unwrap() != saved {
    abort("prune-only final validation mutated its source during checks")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        dae2_final_validation_reference(input)
      } else {
        dae2_finalize_candidate(input)
      },
    )
  })
  if @binary.encode_module(input).unwrap() != saved {
    abort("prune-only final validation mutated its source during measurement")
  }
}

///|
#skip("paired native prune-only validation cost; dedicated performance lane")
test "bench DAE2 final validation prune only types=64 reference" (it : @bench.T) {
  dae2_final_validation_prune_only_bench(it, 64, true)
}

///|
#skip("paired native prune-only validation cost; dedicated performance lane")
test "bench DAE2 final validation prune only types=64 consolidated" (
  it : @bench.T,
) {
  dae2_final_validation_prune_only_bench(it, 64, false)
}

///|
#skip("paired native prune-only validation cost; dedicated performance lane")
test "bench DAE2 final validation prune only types=256 reference" (
  it : @bench.T,
) {
  dae2_final_validation_prune_only_bench(it, 256, true)
}

///|
#skip("paired native prune-only validation cost; dedicated performance lane")
test "bench DAE2 final validation prune only types=256 consolidated" (
  it : @bench.T,
) {
  dae2_final_validation_prune_only_bench(it, 256, false)
}
