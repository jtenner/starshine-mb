///|
fn dae_dead_suffix_borrow_bench(
  it : @bench.T,
  width : Int,
  root_position : Int,
  reference : Bool,
) -> Unit {
  let body = Array::make(width, @lib.Instruction::nop())
  if root_position >= 0 {
    body[root_position] = @lib.Instruction::unreachable_()
  }
  let old = dae_dead_suffix_before_borrow(body)
  let next = dae_dead_suffix_evidence(body)
  match (old, next) {
    (Some(left), Some(right)) => {
      if left.root_idx != right.root_idx ||
        left.suffix_start != right.suffix_start {
        abort("dead suffix boundary changed")
      }
      for index = right.suffix_start; index < body.length(); index = index + 1 {
        if body[index] != left.body[index - right.suffix_start] {
          abort("borrowed suffix changed instruction order")
        }
      }
    }
    (None, None) => ()
    _ => abort("dead suffix existence changed")
  }
  it.bench(fn() {
    it.keep(
      if reference {
        dae_dead_suffix_before_borrow(body)
      } else {
        dae_dead_suffix_evidence(body)
      },
    )
  })
}

///|
test "bench DAE suffix width=4 no-root reference" (it : @bench.T) {
  dae_dead_suffix_borrow_bench(it, 4, -1, true)
}

///|
test "bench DAE suffix width=4 no-root borrowed" (it : @bench.T) {
  dae_dead_suffix_borrow_bench(it, 4, -1, false)
}

///|
test "bench DAE suffix width=4 early-root reference" (it : @bench.T) {
  dae_dead_suffix_borrow_bench(it, 4, 0, true)
}

///|
test "bench DAE suffix width=4 early-root borrowed" (it : @bench.T) {
  dae_dead_suffix_borrow_bench(it, 4, 0, false)
}

///|
test "bench DAE suffix width=4 last-root reference" (it : @bench.T) {
  dae_dead_suffix_borrow_bench(it, 4, 3, true)
}

///|
test "bench DAE suffix width=4 last-root borrowed" (it : @bench.T) {
  dae_dead_suffix_borrow_bench(it, 4, 3, false)
}

///|
test "bench DAE suffix width=128 no-root reference" (it : @bench.T) {
  dae_dead_suffix_borrow_bench(it, 128, -1, true)
}

///|
test "bench DAE suffix width=128 no-root borrowed" (it : @bench.T) {
  dae_dead_suffix_borrow_bench(it, 128, -1, false)
}

///|
test "bench DAE suffix width=128 early-root reference" (it : @bench.T) {
  dae_dead_suffix_borrow_bench(it, 128, 0, true)
}

///|
test "bench DAE suffix width=128 early-root borrowed" (it : @bench.T) {
  dae_dead_suffix_borrow_bench(it, 128, 0, false)
}

///|
test "bench DAE suffix width=128 last-root reference" (it : @bench.T) {
  dae_dead_suffix_borrow_bench(it, 128, 127, true)
}

///|
test "bench DAE suffix width=128 last-root borrowed" (it : @bench.T) {
  dae_dead_suffix_borrow_bench(it, 128, 127, false)
}

///|
test "bench DAE suffix width=4096 no-root reference" (it : @bench.T) {
  dae_dead_suffix_borrow_bench(it, 4096, -1, true)
}

///|
test "bench DAE suffix width=4096 no-root borrowed" (it : @bench.T) {
  dae_dead_suffix_borrow_bench(it, 4096, -1, false)
}

///|
test "bench DAE suffix width=4096 early-root reference" (it : @bench.T) {
  dae_dead_suffix_borrow_bench(it, 4096, 0, true)
}

///|
test "bench DAE suffix width=4096 early-root borrowed" (it : @bench.T) {
  dae_dead_suffix_borrow_bench(it, 4096, 0, false)
}

///|
test "bench DAE suffix width=4096 last-root reference" (it : @bench.T) {
  dae_dead_suffix_borrow_bench(it, 4096, 4095, true)
}

///|
test "bench DAE suffix width=4096 last-root borrowed" (it : @bench.T) {
  dae_dead_suffix_borrow_bench(it, 4096, 4095, false)
}
