///|
fn cl_combined_native_noop_case_0() -> Unit raise {
  ignore(cl_epoch_order_check(cl_epoch_order_body(0), 0, seed=true))
  ignore(cl_epoch_order_check(cl_epoch_order_body(1), 0))
  ignore(cl_epoch_order_check(cl_epoch_order_body(2), 0))
  // A productive copy-source overwrite must keep its original exemption and
  // hazard0/1. This is the installed GREEN direct/public reference fixture.
  ignore(cl_flat_hazard_check(cl_flat_hazard_body(), 6, 0, productive=true))
}

///|
fn cl_combined_native_noop_case_1() -> Unit raise {
  let work = cl_epoch_order_check(cl_epoch_order_body(0), 0, seed=true)
  // The original generic worker needs no compiled steps here. The baseline
  // epoch worker really builds one nonempty step array. Require runtime RED
  // only AFTER all16 matrix bits, public IR/bytes, effects and ownership pass.
  assert_eq(work, [0, 0])
}

///|
fn cl_combined_native_noop_case_2() -> Unit raise {
  let no_read = cl_epoch_order_check(cl_epoch_order_body(2), 0)
  assert_eq(no_read, [0, 0])
  let parameters = cl_epoch_order_check(cl_epoch_order_body(1), 4)
  assert_eq(parameters, [0, 0])
  let reset = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::return_(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ]
  // The existing action collector omits reads after Return. With no other
  // reachable reader the original epoch worker intentionally compiles nothing.
  // This is an existing dead-read omission control, not new guard coverage.
  assert_eq(cl_epoch_order_check(reset, 0), [0, 0])
  let positive_reset = [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
    @lib.Instruction::local_get(@lib.LocalIdx::new(2U)),
    @lib.Instruction::drop(),
    @lib.Instruction::return_(),
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U)),
    @lib.Instruction::drop(),
  ]
  let work = cl_epoch_order_check(positive_reset, 0)
  // The reachable Get2 after Set0 makes the coarse guard positive. The raw
  // step compiler must still emit Reset before the dead Get1. This preserves
  // real hazard0/2 and prevents a false hazard0/1 across Return.
  assert_eq(work[0], 1)
  assert_true(work[1] > 0)
  let actions : Array[CLAction] = []
  cl_collect_instrs(positive_reset, actions, 4)
  assert_eq(actions.length(), 2)
  let matrix = CLBitMatrix::new(4)
  cl_add_linear_source_write_dest_read_interferences(
    positive_reset,
    actions,
    Array::make(actions.length(), true),
    Array::make(4, @lib.ValType::i32()),
    0,
    matrix,
  )
  assert_true(cl_bit_matrix_get(matrix, 0, 2))
  assert_false(cl_bit_matrix_get(matrix, 0, 1))
}

///|
fn cl_combined_native_noop_case_3() -> Unit raise {
  for
    body in [
      [
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::block(
          @lib.BlockType::void_(),
          @lib.Expr::new(cl_epoch_order_body(0)),
        ),
      ],
      [
        @lib.Instruction::call(@lib.FuncIdx::new(0U)),
        @lib.Instruction::loop_(
          @lib.BlockType::void_(),
          @lib.Expr::new(cl_epoch_order_body(0)),
        ),
      ],
    ] {
    let (unused, fallback) = cl_flat_hazard_check(body, 4, 0)
    ignore(unused)
    assert_eq(fallback, 1)
    let work = cl_epoch_order_check(body, 0)
    assert_eq(work, [0, 0])
  }
}

///|
fn cl_combined_native_done_case_0() -> Unit raise {
  ignore(cl_flat_hazard_check(cl_flat_hazard_body(), 6, 0, productive=true))
  for mode in [0, 1, 2] {
    for seed in [false, true] {
      ignore(cl_done_check(3, mode, seed~))
    }
  }
}

///|
fn cl_combined_native_done_case_1() -> Unit raise {
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
fn cl_combined_native_done_case_2() -> Unit raise {
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
