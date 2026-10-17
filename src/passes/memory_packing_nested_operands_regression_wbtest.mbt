///|
fn mp_nested_output(input : @lib.Module) -> @lib.Module raise {
  assert_true(mp_module_segment_op_preflight(input).rewritable)
  let saved = @binary.encode_module(input).unwrap()
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "memory-packing",
  ]).unwrap()
  assert_eq(@binary.encode_module(input).unwrap(), saved)
  let encoded = @binary.encode_module(output).unwrap()
  assert_true(
    @validate.validate_module(@binary.decode_module(encoded).unwrap()) is Ok(_),
  )
  output
}

///|
fn mp_nested_body(mod_ : @lib.Module) -> Array[@lib.Instruction] {
  let @lib.Func(_, @lib.Expr(body)) = mod_.code_sec.unwrap().0[0]
  body
}

///|
fn mp_nested_copy_indices(body : Array[@lib.Instruction]) -> Array[Int32] {
  let indices : Array[Int32] = []
  for instr in body {
    match instr {
      @lib.MemoryInit(idx, _) => indices.push(mp_data_idx_slot(idx))
      _ => ()
    }
  }
  indices
}

///|
// Execute the bounded scalar IR used by the empty-copy fixtures. This checks
// the emitted predicates against Wasm's empty-copy contract, not its shape.
fn mp_nested_empty_copy_traps(
  body : Array[@lib.Instruction],
  locals : Array[UInt64],
  stack : Array[UInt64],
  dropped : Array[UInt64],
) -> Bool {
  for instr in body {
    match instr {
      @lib.I32Const(@lib.I32(value)) =>
        stack.push(value.reinterpret_as_uint().to_uint64())
      @lib.I64Const(@lib.I64(value)) =>
        stack.push(value.reinterpret_as_uint64())
      @lib.LocalGet(@lib.LocalIdx(idx)) => stack.push(locals[idx.to_int()])
      @lib.LocalSet(@lib.LocalIdx(idx)) =>
        locals[idx.to_int()] = stack.pop().unwrap()
      @lib.GlobalGet(@lib.GlobalIdx(idx)) => stack.push(dropped[idx.to_int()])
      @lib.GlobalSet(@lib.GlobalIdx(idx)) =>
        dropped[idx.to_int()] = stack.pop().unwrap()
      @lib.MemorySize(_) => stack.push(1UL)
      @lib.Block(_, @lib.Expr(nested)) =>
        if mp_nested_empty_copy_traps(nested, locals, stack, dropped) {
          return true
        }
      @lib.If(_, yes, no) => {
        let condition = stack.pop().unwrap()
        let branch = if condition != 0UL { yes } else { no.unwrap_or([]) }
        if mp_nested_empty_copy_traps(branch, locals, stack, dropped) {
          return true
        }
      }
      @lib.Unreachable => return true
      @lib.Nop => ()
      @lib.I32Add | @lib.I64Add => {
        let right = stack.pop().unwrap()
        let left = stack.pop().unwrap()
        stack.push(
          (left + right) &
          (if instr is @lib.I32Add {
            0xffffffffUL
          } else {
            0xffffffffffffffffUL
          }),
        )
      }
      @lib.I32Sub | @lib.I64Sub => {
        let right = stack.pop().unwrap()
        let left = stack.pop().unwrap()
        stack.push(
          (left - right) &
          (if instr is @lib.I32Sub {
            0xffffffffUL
          } else {
            0xffffffffffffffffUL
          }),
        )
      }
      @lib.I32And | @lib.I64And => {
        let right = stack.pop().unwrap()
        let left = stack.pop().unwrap()
        stack.push(left & right)
      }
      @lib.I32ShrU | @lib.I64ShrU => {
        let right = stack.pop().unwrap()
        let left = stack.pop().unwrap()
        stack.push(
          left >>
          (right & (if instr is @lib.I32ShrU { 31UL } else { 63UL })).to_int(),
        )
      }
      @lib.I32GtU | @lib.I64GtU => {
        let right = stack.pop().unwrap()
        let left = stack.pop().unwrap()
        stack.push(if left > right { 1UL } else { 0UL })
      }
      @lib.MemoryInit(_, _) | @lib.MemoryFill(_) => {
        ignore(stack.pop().unwrap())
        ignore(stack.pop().unwrap())
        ignore(stack.pop().unwrap())
      }
      _ => abort("unexpected empty-copy evaluation opcode: \{instr}")
    }
  }
  false
}

///|
test "memory-packing extracts outer operands across an already split inner memory.init" {
  let zeros = "\\00".repeat(128)
  // The outer destination remains on the stack while the inner copy runs.
  // Both operations expand, and deleting data 0 changes every retained index.
  for address in ["i32", "i64"] {
    let memory = if address == "i32" { "1" } else { "i64 1" }
    let input = pass_test_module_from_wat(
      "(module (memory \{memory}) (data \"dead\") (data \"A\{zeros}B\") (data \"C\{zeros}D\") (func (param \{address} \{address}) local.get 0 local.get 1 i32.const 0 i32.const 130 memory.init 2 i32.const 0 i32.const 130 memory.init 1))",
    )
    let output = mp_nested_output(input)
    assert_eq(
      output.data_sec.unwrap().0.map(data => {
        let @lib.Data(_, bytes) = data
        bytes
      }),
      [b"A", b"B", b"C", b"D"],
    )
    let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
    assert_eq(locals.length(), 2)
    let address_type = if address == "i32" {
      @lib.ValType::i32()
    } else {
      @lib.ValType::i64()
    }
    assert_eq(locals[0], address_type)
    assert_eq(locals[1], address_type)
    let body = mp_nested_body(output)
    assert_eq(body[0], @lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
    assert_eq(body[1], @lib.Instruction::local_get(@lib.LocalIdx::new(1U)))
    assert_eq(body[2], @lib.Instruction::local_set(@lib.LocalIdx::new(2U)))
    @debug.assert_eq(mp_nested_copy_indices(body), [2, 3, 0, 1])
    let mut outer_set = -1
    let mut inner_last_copy = -1
    let mut fill_count = 0
    let mut checks = 0
    for i = 0; i < body.length(); i = i + 1 {
      match body[i] {
        @lib.LocalSet(idx) => if idx == @lib.LocalIdx::new(3U) { outer_set = i }
        @lib.MemoryInit(idx, _) => {
          if mp_data_idx_slot(idx) == 3 {
            inner_last_copy = i
          }
          assert_true(
            checks >= (if mp_data_idx_slot(idx) >= 2 { 2 } else { 4 }),
          )
        }
        @lib.MemoryFill(_) => fill_count += 1
        @lib.If(_, _, _) => checks += 1
        _ => ()
      }
    }
    assert_true(inner_last_copy >= 0 && outer_set > inner_last_copy)
    assert_eq(fill_count, 2)
  }
}

///|
test "memory-packing nested destination keeps remapped drop probe before leading zero writes" {
  let zeros = "\\00".repeat(128)
  let input = pass_test_module_from_wat(
    "(module (memory 1) (data \"dead\") (data \"\{zeros}A\{zeros}B\") (func (param i32) (memory.init 1 (block (result i32) (data.drop 1) (local.get 0)) (i32.const 0) (i32.const 258))))",
  )
  let output = mp_nested_output(input)
  assert_eq(output.data_sec.unwrap().0.length(), 2)
  let body = mp_nested_body(output)
  match body[0] {
    @lib.Block(_, @lib.Expr(nested)) =>
      @debug.assert_eq(nested, [
        @lib.Instruction::data_drop(@lib.DataIdx::new(0U)),
        @lib.Instruction::data_drop(@lib.DataIdx::new(1U)),
        @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      ])
    _ => fail("expected the destination block to be evaluated once")
  }
  assert_eq(body[1], @lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
  // A zero-length probe with source 1 traps on a dropped retained segment.
  // It must run before the first memory.fill, which would otherwise mutate memory.
  @debug.assert_eq(body[2:6].to_array(), [
    mp_i32_const(0),
    mp_i32_const(1),
    mp_i32_const(0),
    @lib.Instruction::memory_init(@lib.DataIdx::new(0U), @lib.MemIdx::new(0U)),
  ])
  @debug.assert_eq(mp_nested_copy_indices(body), [0, 0, 1])
  let mut preflight_checks = 0
  let mut fills = 0
  for i = 6; i < body.length(); i = i + 1 {
    match body[i] {
      @lib.If(_, _, _) => preflight_checks += 1
      @lib.MemoryFill(_) => {
        fills += 1
        assert_eq(preflight_checks, 2)
      }
      _ => ()
    }
  }
  assert_eq(fills, 2)
}

///|
test "memory-packing nested all-zero destination preserves logical drop state" {
  let zeros = "\\00".repeat(128)
  let input = pass_test_module_from_wat(
    "(module (memory 1) (data \"dead\") (data \"\{zeros}\") (func (param i32) (memory.init 1 (if (result i32) (local.get 0) (then (data.drop 1) (i32.const 8)) (else (i32.const 16))) (i32.const 0) (i32.const 128))))",
  )
  let output = mp_nested_output(input)
  assert_true(output.data_sec is None)
  assert_eq(output.global_sec.unwrap().0.length(), 1)
  let body = mp_nested_body(output)
  match body[1] {
    @lib.If(_, yes, Some(no)) => {
      assert_eq(yes[0], mp_i32_const(1))
      assert_eq(yes[1], @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)))
      assert_eq(yes[yes.length() - 1], mp_i32_const(8))
      @debug.assert_eq(no, [mp_i32_const(16)])
    }
    _ => fail("expected the branch-selected destination and its drop effect")
  }
  assert_eq(body[2], @lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
  assert_eq(body[3], @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)))
  match body[4] {
    @lib.If(_, [@lib.Unreachable], None) => ()
    _ => fail("expected a lifetime trap before destination checks and writes")
  }
  assert_eq(mp_nested_copy_indices(body).length(), 0)
  assert_eq(
    body[body.length() - 1],
    @lib.Instruction::memory_fill(@lib.MemIdx::new(0U)),
  )
}

///|
test "memory-packing intentionally unsupported nested operands reject before segment remapping" {
  let zeros = "\\00".repeat(128)
  // Dynamic source/size, calls, and type-index block signatures are unsupported
  // by the local operand scanner. The complete module must remain unchanged.
  let fixtures = [
    "(module (memory 1) (data \"dead\") (data \"A\{zeros}B\") (func (param i32) (block (memory.init 1 (i32.const 0) (local.get 0) (i32.const 130)))))",
    "(module (memory 1) (data \"dead\") (data \"A\{zeros}B\") (func (param i32) (if (local.get 0) (then (memory.init 1 (i32.const 0) (i32.const 0) (local.get 0))))))",
    "(module (memory 1) (data \"dead\") (data \"A\{zeros}B\") (func $dest (result i32) i32.const 0) (func (memory.init 1 (call $dest) (i32.const 0) (i32.const 130))))",
    "(module (type $dest (func (result i32))) (memory 1) (data \"dead\") (data \"A\{zeros}B\") (func (memory.init 1 (block (type $dest) (i32.const 0)) (i32.const 0) (i32.const 130))))",
  ]
  for fixture in fixtures {
    let input = pass_test_module_from_wat(fixture)
    let original = @binary.encode_module(input).unwrap()
    assert_false(mp_module_segment_op_preflight(input).rewritable)
    let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "memory-packing",
    ]).unwrap()
    assert_eq(@binary.encode_module(output).unwrap(), original)
    assert_eq(@binary.encode_module(input).unwrap(), original)
  }
}

///|
test "memory-packing nested zero-length copies distinguish dropped source bounds" {
  let zeros = "\\00".repeat(128)
  for address in ["i32", "i64"] {
    let memory = if address == "i32" { "1" } else { "i64 1" }
    for source in [0, 128] {
      let input = pass_test_module_from_wat(
        "(module (memory \{memory}) (data \"dead\") (data \"\{zeros}\") (func (param \{address}) (memory.init 1 (block (result \{address}) (data.drop 1) (local.get 0)) (i32.const \{source}) (i32.const 0))))",
      )
      let output = mp_nested_output(input)
      assert_true(output.data_sec is None)
      let body = mp_nested_body(output)
      match body[0] {
        @lib.Block(_, @lib.Expr(nested)) => {
          assert_eq(nested[0], mp_i32_const(1))
          assert_eq(
            nested[1],
            @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
          )
          assert_eq(
            nested[nested.length() - 1],
            @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          )
        }
        _ => fail("expected destination evaluation to retain data.drop")
      }
      assert_eq(body[1], @lib.Instruction::local_set(@lib.LocalIdx::new(1U)))
      let mut lifetime_reads = 0
      let mut destination_checks = 0
      for instr in body {
        match instr {
          @lib.GlobalGet(_) => lifetime_reads += 1
          @lib.MemorySize(_) => destination_checks += 1
          @lib.MemoryInit(_, _) | @lib.MemoryFill(_) =>
            fail("a zero-length copy must not write memory")
          _ => ()
        }
      }
      // (source=0,size=0) remains source-valid after drop; (128,0) traps.
      assert_eq(lifetime_reads, if source == 0 { 0 } else { 1 })
      // Two predicates check the destination page and its endpoint within that
      // page. An endpoint equal to the memory byte length is valid for size zero.
      assert_eq(destination_checks, 2)
      let destinations = if address == "i32" {
        [0UL, 1UL, 65535UL, 65536UL, 65537UL, 0xffffffffUL]
      } else {
        [0UL, 1UL, 65535UL, 65536UL, 65537UL, 0xffffffffffffffffUL]
      }
      for destination in destinations {
        let locals = [destination, 0UL]
        let stack : Array[UInt64] = []
        let dropped = [0UL]
        assert_eq(
          mp_nested_empty_copy_traps(body, locals, stack, dropped),
          source != 0 || destination > 65536UL,
          msg="empty copy trap: \{address}, source=\{source}, destination=\{destination}",
        )
        // Destination evaluation completes, including data.drop, before either
        // the source-lifetime trap or the destination-bounds trap can occur.
        assert_eq(dropped[0], 1UL)
        assert_eq(locals[1], destination)
        assert_eq(stack.length(), 0)
      }
    }
  }
}

///|
test "memory-packing memory64 split checks full destination range before writing" {
  let zeros = "\\00".repeat(128)
  let input = pass_test_module_from_wat(
    "(module (memory i64 1) (data \"A\{zeros}B\") (func (param i64) (memory.init 0 (local.get 0) (i32.const 0) (i32.const 130))))",
  )
  let output = mp_nested_output(input)
  let body = mp_nested_body(output)

  assert_true(output.data_sec.unwrap().0.length() > 1)
  assert_true(body.any(instr => instr is @lib.MemoryFill(_)))
  for
    pair in [
      // The exact endpoint is valid: 65,406 + 130 = 65,536.
      (65406UL, false),
      // One byte beyond the endpoint must trap before the first split write.
      (65407UL, true),
      // A copy cannot start at the endpoint when its length is nonzero.
      (65536UL, true),
      // These additions wrap at UInt64 width. The page preflight must reject the
      // destination before the wrapped endpoint can appear in a later check.
      (0xffffffffffffff80UL, true),
      (0xffffffffffffffffUL, true),
    ] {
    let (destination, expected_trap) = pair
    assert_eq(
      mp_nested_empty_copy_traps(body, [destination, 0UL], [], []),
      expected_trap,
      msg="memory64 split destination=\{destination}",
    )
  }
}
