///|
fn precompute_tail_admission_fixture(
  width : Int,
  shape : String,
) -> @lib.Module {
  let seed = pass_test_module_from_wat(
    "(module (func (param i32) (result i32) local.get 0))",
  )
  let body : Array[@lib.Instruction] = []
  for _ in 0..<width {
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
    body.push(@lib.Instruction::drop())
  }
  match shape {
    "value" => body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
    "constant" => body.push(@lib.Instruction::i32_const(@lib.I32(7)))
    _ => {
      body.push(@lib.Instruction::i32_const(@lib.I32(1)))
      body.push(@lib.Instruction::i32_const(@lib.I32(2)))
      body.push(@lib.Instruction::i32_add())
    }
  }
  seed.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::new([]), @lib.Expr::new(body)),
    ]),
  )
}

///|
fn precompute_root_snapshot_fixture(width : Int, active : Bool) -> @lib.Module {
  let seed = pass_test_module_from_wat(
    "(module (global (mut i32) (i32.const 7)) (func (param i32) (result i32) (local i32) local.get 0))",
  )
  let body : Array[@lib.Instruction] = []
  if active {
    body.push(@lib.Instruction::global_get(@lib.GlobalIdx::new(0U)))
    body.push(@lib.Instruction::local_tee(@lib.LocalIdx::new(1U)))
    body.push(@lib.Instruction::global_get(@lib.GlobalIdx::new(0U)))
    body.push(@lib.Instruction::global_set(@lib.GlobalIdx::new(0U)))
  }
  for _ in 0..<width {
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
    body.push(@lib.Instruction::drop())
  }
  if !active {
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  }
  seed.with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::from_types([@lib.ValType::i32()]),
        @lib.Expr::new(body),
      ),
    ]),
  )
}

///|
fn precompute_tail_admission_bench(
  it : @bench.T,
  width : Int,
  shape : String,
  reference : Bool,
) -> Unit {
  let input = precompute_tail_admission_fixture(width, shape)
  @validate.validate_module(input).unwrap()
  let bytes = @binary.encode_module(input).unwrap()
  let @lib.Func(locals, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let expected = body.copy()
  let output = body.copy()
  let before_changed = precompute_raw_fold_output_tail_reference(expected)
  let changed = precompute_raw_fold_output_tail(output)
  if changed != (shape == "active") ||
    before_changed != changed ||
    output != expected {
    abort("precompute tail admission lost its reference fold")
  }
  @validate.validate_module(
    input.with_code_sec(
      @lib.CodeSec::new([@lib.Func::new(locals, @lib.Expr::new(output))]),
    ),
  ).unwrap()
  if @binary.encode_module(input).unwrap() != bytes {
    abort("precompute tail admission modified the source")
  }
  it.bench(fn() {
    let out = if shape == "active" { body.copy() } else { body }
    it.keep(
      if reference {
        precompute_raw_fold_output_tail_reference(out)
      } else {
        precompute_raw_fold_output_tail(out)
      },
    )
  })
}

///|
fn precompute_root_snapshot_bench(
  it : @bench.T,
  width : Int,
  active : Bool,
  reference : Bool,
) -> Unit {
  let input = precompute_root_snapshot_fixture(width, active)
  @validate.validate_module(input).unwrap()
  let bytes = @binary.encode_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  if precompute_root_snapshot_prefix_reference(body) != active ||
    run_hot_pipeline_raw_has_root_global_snapshot_write_prefix(body) != active {
    abort("root snapshot admission changed the guard decision")
  }
  if @binary.encode_module(input).unwrap() != bytes {
    abort("root snapshot admission modified the source")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        precompute_root_snapshot_prefix_reference(body)
      } else {
        run_hot_pipeline_raw_has_root_global_snapshot_write_prefix(body)
      },
    )
  })
}

///|
test "bench precompute tail width=4 value reference" (it : @bench.T) {
  precompute_tail_admission_bench(it, 4, "value", true)
}

///|
test "bench precompute tail width=4 value admitted" (it : @bench.T) {
  precompute_tail_admission_bench(it, 4, "value", false)
}

///|
test "bench precompute tail width=4 constant reference" (it : @bench.T) {
  precompute_tail_admission_bench(it, 4, "constant", true)
}

///|
test "bench precompute tail width=4 constant admitted" (it : @bench.T) {
  precompute_tail_admission_bench(it, 4, "constant", false)
}

///|
test "bench precompute tail width=4 active reference" (it : @bench.T) {
  precompute_tail_admission_bench(it, 4, "active", true)
}

///|
test "bench precompute tail width=4 active admitted" (it : @bench.T) {
  precompute_tail_admission_bench(it, 4, "active", false)
}

///|
test "bench precompute tail width=128 value reference" (it : @bench.T) {
  precompute_tail_admission_bench(it, 128, "value", true)
}

///|
test "bench precompute tail width=128 value admitted" (it : @bench.T) {
  precompute_tail_admission_bench(it, 128, "value", false)
}

///|
test "bench precompute tail width=128 constant reference" (it : @bench.T) {
  precompute_tail_admission_bench(it, 128, "constant", true)
}

///|
test "bench precompute tail width=128 constant admitted" (it : @bench.T) {
  precompute_tail_admission_bench(it, 128, "constant", false)
}

///|
test "bench precompute tail width=128 active reference" (it : @bench.T) {
  precompute_tail_admission_bench(it, 128, "active", true)
}

///|
test "bench precompute tail width=128 active admitted" (it : @bench.T) {
  precompute_tail_admission_bench(it, 128, "active", false)
}

///|
test "bench precompute tail width=4096 value reference" (it : @bench.T) {
  precompute_tail_admission_bench(it, 4096, "value", true)
}

///|
test "bench precompute tail width=4096 value admitted" (it : @bench.T) {
  precompute_tail_admission_bench(it, 4096, "value", false)
}

///|
test "bench precompute tail width=4096 constant reference" (it : @bench.T) {
  precompute_tail_admission_bench(it, 4096, "constant", true)
}

///|
test "bench precompute tail width=4096 constant admitted" (it : @bench.T) {
  precompute_tail_admission_bench(it, 4096, "constant", false)
}

///|
test "bench precompute tail width=4096 active reference" (it : @bench.T) {
  precompute_tail_admission_bench(it, 4096, "active", true)
}

///|
test "bench precompute tail width=4096 active admitted" (it : @bench.T) {
  precompute_tail_admission_bench(it, 4096, "active", false)
}

///|
test "bench root snapshot prefix width=16 dynamic reference" (it : @bench.T) {
  precompute_root_snapshot_bench(it, 16, false, true)
}

///|
test "bench root snapshot prefix width=16 dynamic streamed" (it : @bench.T) {
  precompute_root_snapshot_bench(it, 16, false, false)
}

///|
test "bench root snapshot prefix width=16 active reference" (it : @bench.T) {
  precompute_root_snapshot_bench(it, 16, true, true)
}

///|
test "bench root snapshot prefix width=16 active streamed" (it : @bench.T) {
  precompute_root_snapshot_bench(it, 16, true, false)
}

///|
test "bench root snapshot prefix width=128 dynamic reference" (it : @bench.T) {
  precompute_root_snapshot_bench(it, 128, false, true)
}

///|
test "bench root snapshot prefix width=128 dynamic streamed" (it : @bench.T) {
  precompute_root_snapshot_bench(it, 128, false, false)
}

///|
test "bench root snapshot prefix width=128 active reference" (it : @bench.T) {
  precompute_root_snapshot_bench(it, 128, true, true)
}

///|
test "bench root snapshot prefix width=128 active streamed" (it : @bench.T) {
  precompute_root_snapshot_bench(it, 128, true, false)
}

///|
test "bench root snapshot prefix width=4096 dynamic reference" (it : @bench.T) {
  precompute_root_snapshot_bench(it, 4096, false, true)
}

///|
test "bench root snapshot prefix width=4096 dynamic streamed" (it : @bench.T) {
  precompute_root_snapshot_bench(it, 4096, false, false)
}

///|
test "bench root snapshot prefix width=4096 active reference" (it : @bench.T) {
  precompute_root_snapshot_bench(it, 4096, true, true)
}

///|
test "bench root snapshot prefix width=4096 active streamed" (it : @bench.T) {
  precompute_root_snapshot_bench(it, 4096, true, false)
}
