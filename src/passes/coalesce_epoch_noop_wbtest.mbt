///|
fn cl_epoch_order_body(mode : Int32) -> Array[@lib.Instruction] {
  let body = [@lib.Instruction::call(@lib.FuncIdx::new(0U))]
  if mode == 0 {
    for local in 0..<4 {
      body.push(
        @lib.Instruction::local_get(@lib.LocalIdx::new(local.to_uint())),
      )
      body.push(@lib.Instruction::drop())
    }
  }
  for _ in 0..<(if mode == 1 { 3 } else { 1 }) {
    for local in 0..<4 {
      body.push(@lib.Instruction::i32_const(@lib.I32(local)))
      body.push(
        @lib.Instruction::local_set(@lib.LocalIdx::new(local.to_uint())),
      )
    }
    if mode == 1 {
      for local in 0..<4 {
        body.push(
          @lib.Instruction::local_get(@lib.LocalIdx::new(local.to_uint())),
        )
        body.push(@lib.Instruction::drop())
      }
    }
  }
  body
}

///|
fn cl_epoch_order_check(
  body : Array[@lib.Instruction],
  param_count : Int32,
  seed~ : Bool = false,
) -> Array[Int32] raise {
  // First check complete generic-reference rewrite/public-output contracts.
  ignore(cl_flat_hazard_check(body, 4, param_count, seed~))
  let input = cl_flat_hazard_module(body, 4, param_count)
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let saved_body = body.copy()
  let actions : Array[CLAction] = []
  cl_collect_instrs(body, actions, 4)
  let effective = Array::make(actions.length(), true)
  let saved_effective = effective.copy()
  let types = Array::make(4, @lib.ValType::i32())
  let actual = CLBitMatrix::new(4)
  let generic = CLBitMatrix::new(4)
  let frozen = CLBitMatrix::new(4)
  let counted = CLBitMatrix::new(4)
  if seed {
    for matrix in [actual, generic, frozen, counted] {
      cl_add_interference(matrix, 0, 2)
    }
  }
  let work = [0, 0]
  cl_add_linear_source_write_dest_read_interferences(
    body, actions, effective, types, param_count, actual,
  )
  cl_epoch_combined_instrumented(
    body,
    actions,
    effective,
    types,
    param_count,
    counted,
    step_work=Some(work),
  )
  cl_add_source_write_dest_read_interferences_reference(
    body, actions, effective, types, param_count, generic,
  )
  cl_epoch_before(body, actions, effective, types, param_count, frozen)
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
    }
  }
  let public_output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "coalesce-locals",
  ]).unwrap()
  let reference = cl_linear_hazard_reference_module(input)
  @validate.validate_module(public_output).unwrap()
  @validate.validate_module(reference).unwrap()
  assert_eq(public_output.code_sec, reference.code_sec)
  assert_eq(
    @binary.encode_module(public_output).unwrap(),
    @binary.encode_module(reference).unwrap(),
  )
  let @lib.Func(_, @lib.Expr(out)) = public_output.code_sec.unwrap().0[0]
  assert_true(out.contains(@lib.Instruction::call(@lib.FuncIdx::new(0U))))
  assert_eq(body, saved_body)
  assert_eq(effective, saved_effective)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  work
}

///|
test "coalesce epoch no-work admission retains read order output effects and existing matrix" {
  ignore(cl_epoch_order_check(cl_epoch_order_body(0), 0, seed=true))
  ignore(cl_epoch_order_check(cl_epoch_order_body(1), 0))
  ignore(cl_epoch_order_check(cl_epoch_order_body(2), 0))
  // A productive copy-source overwrite must keep its original exemption and
  // hazard0/1. This is the installed GREEN direct/public reference fixture.
  ignore(cl_flat_hazard_check(cl_flat_hazard_body(), 6, 0, productive=true))
}

///|
test "coalesce epoch skips actual step compilation when all reads precede source writes" {
  let work = cl_epoch_order_check(cl_epoch_order_body(0), 0, seed=true)
  // The original generic worker needs no compiled steps here. The baseline
  // epoch worker really builds one nonempty step array. Require runtime RED
  // only AFTER all16 matrix bits, public IR/bytes, effects and ownership pass.
  assert_eq(work, [0, 0])
}

///|
test "coalesce epoch no-work admission retains empty readers parameters and reset controls" {
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
test "coalesce epoch no-work admission retains branch and barrier fallback" {
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
