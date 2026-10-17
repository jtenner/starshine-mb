///|
fn cl_done_fixture(
  rounds : Int32,
  mode : Int32,
) -> (Array[@lib.Instruction], Array[@lib.ValType]) {
  let types = Array::makei(4, fn(local) {
    if mode == 2 && local % 2 == 1 {
      @lib.ValType::i64()
    } else {
      @lib.ValType::i32()
    }
  })
  let body = [@lib.Instruction::call(@lib.FuncIdx::new(0U))]
  for _ in 0..<rounds {
    for local in 0..<4 {
      body.push(
        if types[local] == @lib.ValType::i64() {
          @lib.Instruction::i64_const(@lib.I64(local.to_int64()))
        } else {
          @lib.Instruction::i32_const(@lib.I32(local))
        },
      )
      body.push(
        @lib.Instruction::local_set(@lib.LocalIdx::new(local.to_uint())),
      )
    }
    for local in 0..<4 {
      body.push(
        @lib.Instruction::local_get(@lib.LocalIdx::new(local.to_uint())),
      )
      body.push(@lib.Instruction::drop())
    }
    if mode == 1 {
      // First prove0/1, then copy1 into0 and later overwrite1. Both clear
      // sites must preserve a current-row done marker on a future candidate.
      body.push(@lib.Instruction::i32_const(@lib.I32(7)))
      body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
      body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
      body.push(@lib.Instruction::drop())
      body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
      body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(0U)))
      body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
      body.push(@lib.Instruction::drop())
      body.push(@lib.Instruction::i32_const(@lib.I32(8)))
      body.push(@lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
      body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
      body.push(@lib.Instruction::drop())
    }
  }
  if mode == 1 {
    // Reachable read actions above keep the full step route active. The raw
    // dead read is still compiled after Reset and cannot undo known hazards.
    body.push(@lib.Instruction::return_())
    body.push(@lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
    body.push(@lib.Instruction::drop())
  }
  (body, types)
}

///|
fn cl_done_check(
  rounds : Int32,
  mode : Int32,
  seed~ : Bool = false,
) -> Array[Int32] raise {
  let (body, types) = cl_done_fixture(rounds, mode)
  // Exact existing rewrite, complete encoded modules, generic-reference
  // public output, effects and source ownership precede all resource checks.
  ignore(cl_flat_hazard_check(body, 4, 0, local_types=Some(types)))
  let input = cl_flat_hazard_module(body, 4, 0).with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(@lib.Locals::from_types(types), @lib.Expr::new(body)),
    ]),
  )
  @validate.validate_module(input).unwrap()
  let before = @binary.encode_module(input).unwrap()
  let saved_body = body.copy()
  let saved_types = types.copy()
  let actions : Array[CLAction] = []
  cl_collect_instrs(body, actions, 4)
  let effective = Array::make(actions.length(), true)
  let saved_effective = effective.copy()
  let actual = CLBitMatrix::new(4)
  let generic = CLBitMatrix::new(4)
  let frozen = CLBitMatrix::new(4)
  let counted = CLBitMatrix::new(4)
  if seed {
    for source in 0..<4 {
      for dest in (source + 1)..<4 {
        if types[source] == types[dest] {
          for matrix in [actual, generic, frozen, counted] {
            cl_add_interference(matrix, source, dest)
          }
        }
      }
    }
  }
  let work = [0, 0, 0]
  cl_add_linear_source_write_dest_read_interferences(
    body, actions, effective, types, 0, actual,
  )
  cl_epoch_combined_instrumented(
    body,
    actions,
    effective,
    types,
    0,
    counted,
    read_work=Some(work),
  )
  cl_epoch_before(body, actions, effective, types, 0, frozen)
  cl_add_source_write_dest_read_interferences_reference(
    body, actions, effective, types, 0, generic,
  )
  for source in 0..<4 {
    for dest in 0..<4 {
      assert_eq(
        cl_bit_matrix_get(actual, source, dest),
        cl_bit_matrix_get(generic, source, dest),
      )
      assert_eq(
        cl_bit_matrix_get(actual, source, dest),
        cl_bit_matrix_get(frozen, source, dest),
      )
      assert_eq(
        cl_bit_matrix_get(actual, source, dest),
        cl_bit_matrix_get(counted, source, dest),
      )
      // In these bodies every same-typed distinct pair has a real witness.
      assert_eq(
        cl_bit_matrix_get(actual, source, dest),
        source != dest && types[source] == types[dest],
      )
    }
  }
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "coalesce-locals",
  ]).unwrap()
  let reference = cl_linear_hazard_reference_module(input)
  @validate.validate_module(output).unwrap()
  @validate.validate_module(reference).unwrap()
  assert_eq(output.code_sec, reference.code_sec)
  assert_eq(output.func_sec, reference.func_sec)
  assert_eq(output.type_sec, reference.type_sec)
  assert_eq(
    @binary.encode_module(output).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
  let @lib.Func(_, @lib.Expr(out)) = output.code_sec.unwrap().0[0]
  assert_true(out.contains(@lib.Instruction::call(@lib.FuncIdx::new(0U))))
  assert_eq(body, saved_body)
  assert_eq(types, saved_types)
  assert_eq(effective, saved_effective)
  assert_eq(@binary.encode_module(input).unwrap(), before)
  work
}

///|
test "coalesce done pairs retain productive public output and complete repeated mixed matrices" {
  ignore(cl_flat_hazard_check(cl_flat_hazard_body(), 6, 0, productive=true))
  for mode in [0, 1, 2] {
    for seed in [false, true] {
      ignore(cl_done_check(3, mode, seed~))
    }
  }
}

///|
test "coalesce done pairs retain copy reset and fresh independent invocation state" {
  ignore(cl_done_check(1, 1))
  ignore(cl_done_check(3, 1))
  ignore(cl_done_check(3, 1))
  ignore(cl_done_check(1, 2, seed=true))
  ignore(cl_done_check(3, 0))
  // The old coarse no-work control and generic fallback keep their exact
  // reference matrices/public modules. This trial changes no admission.
  ignore(cl_epoch_order_check(cl_epoch_order_body(0), 0, seed=true))
  for
    body in [
      [
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new(cl_epoch_order_body(1)),
        ),
      ],
      [
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new(cl_epoch_order_body(1)),
        ),
      ],
    ] {
    let (_, fallback) = cl_flat_hazard_check(body, 4, 0)
    assert_eq(fallback, 1)
  }
}

///|
test "coalesce done pairs remove actual repeated read state and type matrix queries after full behavior" {
  // All full behavior gates above also run inside each counted call. For a
  // four-local three-round all-i32 body the old worker executes48 unsettled
  // reads and18 type/matrix tests. Done pairs need28/6/6. This must reach real
  // runtime RED before implementation; counters instrument actual old sites.
  let work = cl_done_check(3, 0)
  assert_eq(work, [28, 6, 6])
  // Seeded edges and incompatible pairs must also become done at their FIRST
  // witness; only marking newly added edges is an incomplete optimization.
  assert_eq(cl_done_check(3, 0, seed=true), [28, 6, 6])
  assert_eq(cl_done_check(3, 2), [28, 6, 2])
  assert_eq(cl_done_check(3, 2, seed=true), [28, 6, 2])
  // Seven distinct oriented nonself witnesses occur in the copy/reset body.
  // Ordinary destination writes AND copied-destination clears must preserve
  // done stamps, and Reset cannot make a settled matrix pair undecided again.
  let copy_reset = cl_done_check(3, 1)
  assert_eq(copy_reset[1], 7)
  assert_eq(copy_reset[2], 7)
}

///|
#skip("Dedicated multiwrite width control; not a default stress test")
test "coalesce done pairs retain exact repeated matrices across additional rounds" {
  for mode in [0, 1, 2] {
    for seed in [false, true] {
      ignore(cl_done_check(32, mode, seed~))
    }
  }
}
