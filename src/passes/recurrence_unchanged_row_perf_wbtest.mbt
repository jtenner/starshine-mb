///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_three_local_additive_recurrences_flat_copy_reference(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Int) {
  let rewritten : Array[@lib.Instruction] = []
  let mut copy_start = 0
  let mut idx = 0
  let mut rewrite_count = 0
  while idx + 19 < instrs.length() {
    let (seed, first, second, third) = match
      (
        instrs[idx],
        instrs[idx + 1],
        instrs[idx + 2],
        instrs[idx + 3],
        instrs[idx + 4],
        instrs[idx + 5],
        instrs[idx + 6],
        instrs[idx + 7],
        instrs[idx + 8],
        instrs[idx + 9],
      ) {
      (
        @lib.LocalGet(seed),
        @lib.LocalGet(second),
        @lib.I32Add,
        @lib.LocalTee(first),
        @lib.LocalGet(third),
        @lib.I32Add,
        @lib.LocalTee(written_second),
        @lib.LocalGet(read_first),
        @lib.I32Add,
        @lib.LocalSet(written_third),
      ) if written_second == second &&
        read_first == first &&
        written_third == third &&
        seed != first &&
        seed != second &&
        seed != third &&
        first != second &&
        first != third &&
        second != third => (seed, first, second, third)
      _ => {
        idx = idx + 1
        continue
      }
    }
    let mut recurrence_end = idx
    let mut recurrence_count = 0
    while recurrence_end + 9 < instrs.length() {
      match
        (
          instrs[recurrence_end],
          instrs[recurrence_end + 1],
          instrs[recurrence_end + 2],
          instrs[recurrence_end + 3],
          instrs[recurrence_end + 4],
          instrs[recurrence_end + 5],
          instrs[recurrence_end + 6],
          instrs[recurrence_end + 7],
          instrs[recurrence_end + 8],
          instrs[recurrence_end + 9],
        ) {
        (
          @lib.LocalGet(read_seed),
          @lib.LocalGet(read_second),
          @lib.I32Add,
          @lib.LocalTee(write_first),
          @lib.LocalGet(read_third),
          @lib.I32Add,
          @lib.LocalTee(write_second),
          @lib.LocalGet(read_first),
          @lib.I32Add,
          @lib.LocalSet(write_third),
        ) if read_seed == seed &&
          read_second == second &&
          write_first == first &&
          read_third == third &&
          write_second == second &&
          read_first == first &&
          write_third == third => {
          recurrence_count = recurrence_count + 1
          recurrence_end = recurrence_end + 10
        }
        _ => break
      }
    }
    if recurrence_count < 2 {
      idx = idx + 1
      continue
    }
    for copy_idx = copy_start; copy_idx < idx; copy_idx = copy_idx + 1 {
      rewritten.push(instrs[copy_idx])
    }
    rewritten.push(@lib.Instruction::local_get(third))
    for recurrence = 0
        recurrence < recurrence_count
        recurrence = recurrence + 1 {
      let recurrence_start = idx + recurrence * 10
      rewritten.push(instrs[recurrence_start])
      rewritten.push(instrs[recurrence_start + 1])
      rewritten.push(instrs[recurrence_start + 2])
      rewritten.push(instrs[recurrence_start + 3])
      rewritten.push(instrs[recurrence_start + 5])
      rewritten.push(instrs[recurrence_start + 6])
      rewritten.push(instrs[recurrence_start + 7])
      rewritten.push(instrs[recurrence_start + 8])
      if recurrence + 1 == recurrence_count {
        rewritten.push(@lib.Instruction::local_set(third))
      } else {
        rewritten.push(@lib.Instruction::local_tee(third))
      }
    }
    rewrite_count = rewrite_count + recurrence_count
    copy_start = recurrence_end
    idx = recurrence_end
  }
  for copy_idx = copy_start; copy_idx < instrs.length(); copy_idx = copy_idx + 1 {
    rewritten.push(instrs[copy_idx])
  }
  (rewritten, rewrite_count)
}

///|
fn run_hot_pipeline_raw_simplify_locals_rewrite_alternating_bitselect_recurrences_flat_copy_reference(
  instrs : Array[@lib.Instruction],
) -> (Array[@lib.Instruction], Int) {
  let rewritten : Array[@lib.Instruction] = []
  let mut copy_start = 0
  let mut idx = 0
  let mut rewrite_count = 0
  while idx + 19 < instrs.length() {
    let (left, right, mask) = match
      (
        instrs[idx],
        instrs[idx + 1],
        instrs[idx + 2],
        instrs[idx + 3],
        instrs[idx + 4],
        instrs[idx + 5],
        instrs[idx + 6],
        instrs[idx + 7],
        instrs[idx + 8],
        instrs[idx + 9],
      ) {
      (
        @lib.LocalGet(left),
        @lib.LocalGet(right),
        mask,
        @lib.V128Bitselect,
        @lib.LocalSet(write_left),
        @lib.LocalGet(read_right),
        @lib.LocalGet(read_left),
        repeated_mask,
        @lib.V128Bitselect,
        @lib.LocalSet(write_right),
      ) if left != right &&
        write_left == left &&
        read_right == right &&
        read_left == left &&
        write_right == right &&
        mask is @lib.V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) &&
        repeated_mask == mask => (left, right, mask)
      _ => {
        idx = idx + 1
        continue
      }
    }
    let mut recurrence_end = idx
    let mut recurrence_count = 0
    while recurrence_end + 9 < instrs.length() {
      match
        (
          instrs[recurrence_end],
          instrs[recurrence_end + 1],
          instrs[recurrence_end + 2],
          instrs[recurrence_end + 3],
          instrs[recurrence_end + 4],
          instrs[recurrence_end + 5],
          instrs[recurrence_end + 6],
          instrs[recurrence_end + 7],
          instrs[recurrence_end + 8],
          instrs[recurrence_end + 9],
        ) {
        (
          @lib.LocalGet(read_left),
          @lib.LocalGet(read_right),
          first_mask,
          @lib.V128Bitselect,
          @lib.LocalSet(write_left),
          @lib.LocalGet(read_right_again),
          @lib.LocalGet(read_left_again),
          second_mask,
          @lib.V128Bitselect,
          @lib.LocalSet(write_right),
        ) if read_left == left &&
          read_right == right &&
          first_mask == mask &&
          write_left == left &&
          read_right_again == right &&
          read_left_again == left &&
          second_mask == mask &&
          write_right == right => {
          recurrence_count = recurrence_count + 1
          recurrence_end = recurrence_end + 10
        }
        _ => break
      }
    }
    if recurrence_count < 2 {
      idx = idx + 1
      continue
    }
    for copy_idx = copy_start; copy_idx < idx; copy_idx = copy_idx + 1 {
      rewritten.push(instrs[copy_idx])
    }
    rewritten.push(@lib.Instruction::local_get(right))
    for recurrence = 0
        recurrence < recurrence_count
        recurrence = recurrence + 1 {
      let recurrence_start = idx + recurrence * 10
      rewritten.push(instrs[recurrence_start])
      rewritten.push(instrs[recurrence_start + 1])
      rewritten.push(instrs[recurrence_start + 2])
      rewritten.push(instrs[recurrence_start + 3])
      rewritten.push(@lib.Instruction::local_tee(left))
      rewritten.push(instrs[recurrence_start + 7])
      rewritten.push(instrs[recurrence_start + 8])
      if recurrence + 1 == recurrence_count {
        rewritten.push(@lib.Instruction::local_set(right))
      } else {
        rewritten.push(@lib.Instruction::local_tee(right))
      }
    }
    rewrite_count = rewrite_count + recurrence_count
    copy_start = recurrence_end
    idx = recurrence_end
  }
  for copy_idx = copy_start; copy_idx < instrs.length(); copy_idx = copy_idx + 1 {
    rewritten.push(instrs[copy_idx])
  }
  (rewritten, rewrite_count)
}

///|
fn recurrence_row_bench(
  it : @bench.T,
  simd : Bool,
  active : Bool,
  reference : Bool,
) -> Unit raise {
  let body = if active {
    let step = if simd {
      "local.get 0 local.get 1 v128.const i32x4 1 2 3 4 v128.bitselect local.set 0 local.get 1 local.get 0 v128.const i32x4 1 2 3 4 v128.bitselect local.set 1"
    } else {
      "local.get 0 local.get 2 i32.add local.tee 1 local.get 3 i32.add local.tee 2 local.get 1 i32.add local.set 3"
    }
    let prefix = if simd {
      "(param v128 v128)"
    } else {
      "(param i32) (local i32 i32 i32)"
    }
    let text = Array::make(128, step).join(" ")
    let input = pass_test_module_from_wat("(module (func \{prefix} \{text}))")
    let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
    body
  } else {
    Array::make(1024, @lib.Instruction::nop())
  }
  let old = if simd {
    run_hot_pipeline_raw_simplify_locals_rewrite_alternating_bitselect_recurrences_flat_copy_reference
  } else {
    run_hot_pipeline_raw_simplify_locals_rewrite_three_local_additive_recurrences_flat_copy_reference
  }
  let current = if simd {
    run_hot_pipeline_raw_simplify_locals_rewrite_alternating_bitselect_recurrences_flat
  } else {
    run_hot_pipeline_raw_simplify_locals_rewrite_three_local_additive_recurrences_flat
  }
  assert_eq(current(body), old(body))
  assert_eq(current(body).1, if active { 128 } else { 0 })
  let rewrite = if reference { old } else { current }
  it.bench(fn() { it.keep(rewrite(body)) })
}

///|
test "bench recurrence row additive unchanged1024 copy original" (it : @bench.T) {
  recurrence_row_bench(it, false, false, true)
}

///|
test "bench recurrence row additive unchanged1024 current" (it : @bench.T) {
  recurrence_row_bench(it, false, false, false)
}

///|
test "bench recurrence row additive active128 copy original" (it : @bench.T) {
  recurrence_row_bench(it, false, true, true)
}

///|
test "bench recurrence row additive active128 current" (it : @bench.T) {
  recurrence_row_bench(it, false, true, false)
}

///|
test "bench recurrence row bitselect unchanged1024 copy original" (
  it : @bench.T,
) {
  recurrence_row_bench(it, true, false, true)
}

///|
test "bench recurrence row bitselect unchanged1024 current" (it : @bench.T) {
  recurrence_row_bench(it, true, false, false)
}

///|
test "bench recurrence row bitselect active128 copy original" (it : @bench.T) {
  recurrence_row_bench(it, true, true, true)
}

///|
test "bench recurrence row bitselect active128 current" (it : @bench.T) {
  recurrence_row_bench(it, true, true, false)
}
