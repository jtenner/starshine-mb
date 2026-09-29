///|
fn dae_code_snapshot_identity_bench(
  it : @bench.T,
  count : Int,
  mode : Int,
  reference : Bool,
) -> Unit {
  let left : Array[@lib.Func] = []
  for _ in 0..<count {
    left.push(
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new(Array::make(32, @lib.Instruction::nop())),
      ),
    )
  }
  let right = if mode == 0 { left } else { left.copy() }
  if mode == 2 {
    for index = 0; index < right.length(); index = index + 1 {
      let @lib.Func(locals, @lib.Expr(body)) = right[index]
      right[index] = @lib.Func::new(locals, @lib.Expr::new(body.copy()))
    }
  }
  if mode == 3 {
    right[count - 1] = @lib.Func::new(
      @lib.Locals::empty(),
      @lib.Expr::new([@lib.Instruction::unreachable_()]),
    )
  }
  let expected = mode != 3
  if (left == right) != expected ||
    dae_snapshot_funcs_unchanged(left, right) != expected {
    abort("code snapshot comparison changed a distinct body")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        left == right
      } else {
        dae_snapshot_funcs_unchanged(left, right)
      },
    )
  })
}

///|
test "bench DAE code snapshot functions=4 same-array reference" (it : @bench.T) {
  dae_code_snapshot_identity_bench(it, 4, 0, true)
}

///|
test "bench DAE code snapshot functions=4 same-array identity" (it : @bench.T) {
  dae_code_snapshot_identity_bench(it, 4, 0, false)
}

///|
test "bench DAE code snapshot functions=4 shared-functions reference" (
  it : @bench.T,
) {
  dae_code_snapshot_identity_bench(it, 4, 1, true)
}

///|
test "bench DAE code snapshot functions=4 shared-functions identity" (
  it : @bench.T,
) {
  dae_code_snapshot_identity_bench(it, 4, 1, false)
}

///|
test "bench DAE code snapshot functions=4 distinct-bodies reference" (
  it : @bench.T,
) {
  dae_code_snapshot_identity_bench(it, 4, 2, true)
}

///|
test "bench DAE code snapshot functions=4 distinct-bodies identity" (
  it : @bench.T,
) {
  dae_code_snapshot_identity_bench(it, 4, 2, false)
}

///|
test "bench DAE code snapshot functions=4 last-changed reference" (
  it : @bench.T,
) {
  dae_code_snapshot_identity_bench(it, 4, 3, true)
}

///|
test "bench DAE code snapshot functions=4 last-changed identity" (it : @bench.T) {
  dae_code_snapshot_identity_bench(it, 4, 3, false)
}

///|
test "bench DAE code snapshot functions=128 same-array reference" (
  it : @bench.T,
) {
  dae_code_snapshot_identity_bench(it, 128, 0, true)
}

///|
test "bench DAE code snapshot functions=128 same-array identity" (it : @bench.T) {
  dae_code_snapshot_identity_bench(it, 128, 0, false)
}

///|
test "bench DAE code snapshot functions=128 shared-functions reference" (
  it : @bench.T,
) {
  dae_code_snapshot_identity_bench(it, 128, 1, true)
}

///|
test "bench DAE code snapshot functions=128 shared-functions identity" (
  it : @bench.T,
) {
  dae_code_snapshot_identity_bench(it, 128, 1, false)
}

///|
test "bench DAE code snapshot functions=128 distinct-bodies reference" (
  it : @bench.T,
) {
  dae_code_snapshot_identity_bench(it, 128, 2, true)
}

///|
test "bench DAE code snapshot functions=128 distinct-bodies identity" (
  it : @bench.T,
) {
  dae_code_snapshot_identity_bench(it, 128, 2, false)
}

///|
test "bench DAE code snapshot functions=128 last-changed reference" (
  it : @bench.T,
) {
  dae_code_snapshot_identity_bench(it, 128, 3, true)
}

///|
test "bench DAE code snapshot functions=128 last-changed identity" (
  it : @bench.T,
) {
  dae_code_snapshot_identity_bench(it, 128, 3, false)
}

///|
test "bench DAE code snapshot functions=1024 same-array reference" (
  it : @bench.T,
) {
  dae_code_snapshot_identity_bench(it, 1024, 0, true)
}

///|
test "bench DAE code snapshot functions=1024 same-array identity" (
  it : @bench.T,
) {
  dae_code_snapshot_identity_bench(it, 1024, 0, false)
}

///|
test "bench DAE code snapshot functions=1024 shared-functions reference" (
  it : @bench.T,
) {
  dae_code_snapshot_identity_bench(it, 1024, 1, true)
}

///|
test "bench DAE code snapshot functions=1024 shared-functions identity" (
  it : @bench.T,
) {
  dae_code_snapshot_identity_bench(it, 1024, 1, false)
}

///|
test "bench DAE code snapshot functions=1024 distinct-bodies reference" (
  it : @bench.T,
) {
  dae_code_snapshot_identity_bench(it, 1024, 2, true)
}

///|
test "bench DAE code snapshot functions=1024 distinct-bodies identity" (
  it : @bench.T,
) {
  dae_code_snapshot_identity_bench(it, 1024, 2, false)
}

///|
test "bench DAE code snapshot functions=1024 last-changed reference" (
  it : @bench.T,
) {
  dae_code_snapshot_identity_bench(it, 1024, 3, true)
}

///|
test "bench DAE code snapshot functions=1024 last-changed identity" (
  it : @bench.T,
) {
  dae_code_snapshot_identity_bench(it, 1024, 3, false)
}
