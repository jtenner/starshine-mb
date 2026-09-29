///|
fn cmd_input_reuse_identity_bench(
  it : @bench.T,
  width : Int,
  nan : Bool,
  reference : Bool,
  clean? : Bool = false,
) -> Unit {
  let body = if clean {
    let instructions : Array[@lib.Instruction] = []
    for index = 0; index < width; index = index + 1 {
      instructions.push(@lib.Instruction::i32_const(@lib.I32(0)))
      instructions.push(@lib.Instruction::drop())
    }
    instructions
  } else {
    Array::make(width, @lib.Instruction::nop())
  }
  body.push(
    @lib.Instruction::f32_const(
      @lib.F32(
        if nan {
          Float::reinterpret_from_uint(0x7fc00001U)
        } else {
          1.0
        },
      ),
    ),
  )
  let mod_ = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::f32()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(body)),
      ]),
    )
  @validate.validate_module(mod_).unwrap()
  let before = @binary.encode_module(mod_).unwrap()
  if should_reuse_input_wasm_bytes(CliInputFormat::wasm(), 1, false, mod_, mod_) !=
    (!nan || clean) {
    abort("input reuse did not preserve encoding cleanup admission")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        mod_ == mod_
      } else {
        should_reuse_input_wasm_bytes(
          CliInputFormat::wasm(),
          1,
          false,
          mod_,
          mod_,
        )
      },
    )
  })
  if @binary.encode_module(mod_).unwrap() != before {
    abort("reuse proof changed the source module")
  }
}

///|
test "bench CLI input reuse width=4 finite reference" (it : @bench.T) {
  cmd_input_reuse_identity_bench(it, 4, false, true)
}

///|
test "bench CLI input reuse width=4 finite identity" (it : @bench.T) {
  cmd_input_reuse_identity_bench(it, 4, false, false)
}

///|
test "bench CLI input reuse width=4 nan reference" (it : @bench.T) {
  cmd_input_reuse_identity_bench(it, 4, true, true)
}

///|
test "bench CLI input reuse width=4 nan identity" (it : @bench.T) {
  cmd_input_reuse_identity_bench(it, 4, true, false)
}

///|
test "bench CLI input reuse width=128 finite reference" (it : @bench.T) {
  cmd_input_reuse_identity_bench(it, 128, false, true)
}

///|
test "bench CLI input reuse width=128 finite identity" (it : @bench.T) {
  cmd_input_reuse_identity_bench(it, 128, false, false)
}

///|
test "bench CLI input reuse width=128 nan reference" (it : @bench.T) {
  cmd_input_reuse_identity_bench(it, 128, true, true)
}

///|
test "bench CLI input reuse width=128 nan identity" (it : @bench.T) {
  cmd_input_reuse_identity_bench(it, 128, true, false)
}

///|
test "bench CLI input reuse width=4096 finite reference" (it : @bench.T) {
  cmd_input_reuse_identity_bench(it, 4096, false, true)
}

///|
test "bench CLI input reuse width=4096 finite identity" (it : @bench.T) {
  cmd_input_reuse_identity_bench(it, 4096, false, false)
}

///|
test "bench CLI input reuse width=4096 nan reference" (it : @bench.T) {
  cmd_input_reuse_identity_bench(it, 4096, true, true)
}

///|
test "bench CLI input reuse width=4096 nan identity" (it : @bench.T) {
  cmd_input_reuse_identity_bench(it, 4096, true, false)
}

///|
test "bench CLI clean NaN input reuse width=4 reference" (it : @bench.T) {
  cmd_input_reuse_identity_bench(it, 4, true, true, clean=true)
}

///|
test "bench CLI clean NaN input reuse width=4 guarded identity" (it : @bench.T) {
  cmd_input_reuse_identity_bench(it, 4, true, false, clean=true)
}

///|
test "bench CLI clean NaN input reuse width=128 reference" (it : @bench.T) {
  cmd_input_reuse_identity_bench(it, 128, true, true, clean=true)
}

///|
test "bench CLI clean NaN input reuse width=128 guarded identity" (
  it : @bench.T,
) {
  cmd_input_reuse_identity_bench(it, 128, true, false, clean=true)
}

///|
test "bench CLI clean NaN input reuse width=4096 reference" (it : @bench.T) {
  cmd_input_reuse_identity_bench(it, 4096, true, true, clean=true)
}

///|
test "bench CLI clean NaN input reuse width=4096 guarded identity" (
  it : @bench.T,
) {
  cmd_input_reuse_identity_bench(it, 4096, true, false, clean=true)
}
