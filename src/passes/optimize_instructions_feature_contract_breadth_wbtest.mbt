///|
fn oi_feature_breadth_count(
  body : Array[@lib.Instruction],
  predicate : (@lib.Instruction) -> Bool,
) -> Int32 {
  let mut count = 0
  for instr in body {
    if predicate(instr) {
      count += 1
    }
    match instr {
      @lib.Block(_, @lib.Expr(child))
      | @lib.Loop(_, @lib.Expr(child))
      | @lib.TryTable(_, _, @lib.Expr(child)) =>
        count += oi_feature_breadth_count(child, predicate)
      @lib.If(_, then_body, else_body) => {
        count += oi_feature_breadth_count(then_body, predicate)
        match else_body {
          Some(child) => count += oi_feature_breadth_count(child, predicate)
          None => ()
        }
      }
      _ => ()
    }
  }
  count
}

///|
fn oi_feature_breadth_module(
  payloads : Array[Bytes],
  size : Int32,
  memory64~ : Bool = false,
  copy~ : Bool = false,
) -> @lib.Module {
  let address_type = if memory64 {
    @lib.ValType::i64()
  } else {
    @lib.ValType::i32()
  }
  let params = if copy { [address_type, address_type] } else { [address_type] }
  let size_instr = if memory64 {
    @lib.Instruction::i64_const(@lib.I64(size.to_int64()))
  } else {
    @lib.Instruction::i32_const(@lib.I32(size))
  }
  let operand = if copy {
    @lib.Instruction::local_get(@lib.LocalIdx::new(1U))
  } else {
    @lib.Instruction::i32_const(@lib.I32(171))
  }
  let bulk = if copy {
    @lib.Instruction::memory_copy(@lib.MemIdx::new(0U), @lib.MemIdx::new(0U))
  } else {
    @lib.Instruction::memory_fill(@lib.MemIdx::new(0U))
  }
  @lib.Module::new()
  .with_type_sec(
    @lib.TypeSec::new([
      @lib.RecType::new(
        @lib.SubType::comp_type(@lib.CompType::func(params, [])),
      ),
    ]),
  )
  .with_func_sec(@lib.FuncSec::new([@lib.TypeIdx::new(0U)]))
  .with_mem_sec(
    @lib.MemSec::new([
      @lib.MemType::new(
        if memory64 {
          @lib.Limits::i64(1UL, None)
        } else {
          @lib.Limits::i32(1U, None)
        },
      ),
    ]),
  )
  .with_code_sec(
    @lib.CodeSec::new([
      @lib.Func::new(
        @lib.Locals::empty(),
        @lib.Expr::new([
          @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
          operand,
          size_instr,
          bulk,
        ]),
      ),
    ]),
  )
  .with_custom_secs(
    payloads.map(fn(payload) {
      @lib.CustomSec::new(@lib.Name::new("target_features"), payload)
    }),
  )
}

///|
fn oi_feature_breadth_assert(
  input : @lib.Module,
  expect_bulk : Bool,
  expect_simd : Bool,
  shrink_level~ : Int32 = 0,
  stack_function_passes~ : Bool = false,
) -> Unit raise {
  ignore(@validate.validate_module(input).unwrap())
  let output = run_hot_pipeline(
    input,
    HotPipelineOptions::new(shrink_level~, stack_function_passes~),
    ["optimize-instructions", "optimize-instructions"],
  ).unwrap()
  ignore(@validate.validate_module(output).unwrap())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_eq(
    oi_feature_breadth_count(body, fn(instr) {
      instr is @lib.MemoryFill(_) || instr is @lib.MemoryCopy(_, _)
    }),
    if expect_bulk {
      1
    } else {
      0
    },
  )
  assert_eq(
    oi_feature_breadth_count(body, fn(instr) { instr is @lib.V128Store(_) }),
    if expect_simd {
      1
    } else {
      0
    },
  )
  let scalar_stores = oi_feature_breadth_count(body, fn(instr) {
    instr is @lib.I64Store(_) ||
    instr is @lib.I32Store(_) ||
    instr is @lib.I32Store8(_) ||
    instr is @lib.I32Store16(_)
  })
  assert_eq(
    scalar_stores,
    if !expect_bulk && !expect_simd {
      1
    } else {
      0
    },
    msg="scalar lowering must write once; retained bulk operations must not gain partial-write stores",
  )
  assert_eq(output.custom_secs, input.custom_secs)
  let bytes = @binary.encode_module(output).unwrap()
  let decoded = @binary.decode_module(bytes).unwrap()
  ignore(@validate.validate_module(decoded).unwrap())
}

///|
test "feature contracts allow tiny SIMD fill and copy when no SIMD ban exists" {
  for
    payloads in [
      [],
      [b"\x00"],
      [b"\x01\x2b\x07simd128"],
      [b"\x01\x2d\x09tail-call"],
    ] {
    for memory64 in [false, true] {
      for copy in [false, true] {
        oi_feature_breadth_assert(
          oi_feature_breadth_module(payloads, 16, memory64~, copy~),
          false,
          true,
        )
      }
    }
  }
}

///|
test "feature contracts preserve SIMD bans in either repeated section order" {
  let enabled = b"\x01\x2b\x07simd128"
  let disabled = b"\x01\x2d\x07simd128"
  for
    payloads in [
      [enabled, disabled],
      [disabled, enabled],
      [b"\x02\x2b\x07simd128\x2d\x07simd128"],
      [b"\x02\x2d\x07simd128\x2b\x07simd128"],
    ] {
    for memory64 in [false, true] {
      for copy in [false, true] {
        for stack_function_passes in [false, true] {
          oi_feature_breadth_assert(
            oi_feature_breadth_module(payloads, 16, memory64~, copy~),
            true,
            false,
            stack_function_passes~,
          )
        }
      }
    }
  }
}

///|
test "intentionally malformed feature metadata forbids SIMD introduction" {
  // Truncated names/counts, invalid prefixes, trailing bytes and invalid UTF-8
  // are invalid contracts. Preserve bulk traps rather than add SIMD or split stores.
  for
    payload in [
      b"", b"\x80", b"\x01\x2b", b"\x01\x3f\x07simd128", b"\x00\xff", b"\x01\x2b\x01\xff",
      b"\x02\x2b\x07simd128",
    ] {
    for memory64 in [false, true] {
      for copy in [false, true] {
        oi_feature_breadth_assert(
          oi_feature_breadth_module([payload], 16, memory64~, copy~),
          true,
          false,
        )
      }
    }
  }
}

///|
test "SIMD bans do not prevent scalar tiny fill or copy lowering" {
  for payload in [b"\x01\x2d\x07simd128", b""] {
    for size in [1, 2, 4, 8] {
      for memory64 in [false, true] {
        for copy in [false, true] {
          oi_feature_breadth_assert(
            oi_feature_breadth_module([payload], size, memory64~, copy~),
            false,
            false,
          )
        }
      }
    }
  }
}

///|
test "tiny SIMD fill and copy preserve shrink and per-module feature contracts" {
  for payloads in [[], [b"\x01\x2b\x07simd128"], [b"\x01\x2d\x07simd128"]] {
    for shrink_level in [1, 2] {
      for copy in [false, true] {
        oi_feature_breadth_assert(
          oi_feature_breadth_module(payloads, 16, copy~),
          true,
          false,
          shrink_level~,
        )
      }
    }
  }
  // A new pipeline must not inherit an earlier module's explicit ban.
  oi_feature_breadth_assert(
    oi_feature_breadth_module([b"\x01\x2d\x07simd128"], 16),
    true,
    false,
  )
  oi_feature_breadth_assert(oi_feature_breadth_module([], 16), false, true)
}
