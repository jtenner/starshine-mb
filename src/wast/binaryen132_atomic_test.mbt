///|
test "Binaryen 132 text roundtrip retains relaxed and acquire-release orders" {
  for order in ["relaxed", "acq_rel", "seq_cst"] {
    let source = "(module (type (struct (field (mut i32)))) (func (param (ref 0)) (result i32) (struct.atomic.get \{order} 0 0 (local.get 0))))"
    let parsed = match wast_to_module(source) {
      Ok(value) => value
      Err(err) => fail("expected ordered atomic parse: \{err}")
    }
    let printed = match module_to_wast(parsed) {
      Ok(value) => value
      Err(err) => fail("expected ordered atomic print: \{err}")
    }
    assert_true(printed.contains("struct.atomic.get \{order} 0 0"))
    let reparsed = match wast_to_module(printed) {
      Ok(value) => value
      Err(err) => fail("expected ordered atomic reparse: \{err}")
    }
    @debug.assert_eq(reparsed.fields, parsed.fields)
  }
}

///|
test "Binaryen 132 aggregate read modify write text preserves matched order pairs" {
  for order in ["seqcst", "acqrel", "relaxed"] {
    for
      entry in [
        ("struct.atomic.rmw.add", "0 0 (local.get 0) (i32.const 1)"),
        (
          "struct.atomic.rmw.cmpxchg", "0 0 (local.get 0) (i32.const 1) (i32.const 2)",
        ),
        ("array.atomic.rmw.xchg", "1 (local.get 1) (i32.const 0) (i32.const 1)"),
        (
          "array.atomic.rmw.cmpxchg", "1 (local.get 1) (i32.const 0) (i32.const 1) (i32.const 2)",
        ),
      ] {
      let (op, operands) = entry
      let source = "(module (type (struct (field (mut i32)))) (type (array (mut i32))) (func (param (ref 0) (ref 1)) (result i32) (\{op} \{order} \{order} \{operands})))"
      let parsed = match wast_to_module(source) {
        Ok(value) => value
        Err(err) => fail("matched RMW orders: \{err}")
      }
      let printed = module_to_wast(parsed).unwrap()
      let lowered = wast_to_binary_module(printed).unwrap()
      let @lib.CodeSec(bodies) = lowered.code_sec.unwrap()
      let @lib.Func(_, @lib.Expr(body)) = bodies[0]
      let expected = match order {
        "relaxed" => @lib.AtomicOrder::relaxed()
        "acqrel" => @lib.AtomicOrder::acq_rel()
        _ => @lib.AtomicOrder::seq_cst()
      }
      match body[body.length() - 1] {
        @lib.StructAtomicRmw(actual, _, _, _)
        | @lib.StructAtomicCmpxchg(actual, _, _)
        | @lib.ArrayAtomicRmw(actual, _, _)
        | @lib.ArrayAtomicCmpxchg(actual, _) =>
          @debug.assert_eq(actual, expected)
        _ => fail("expected lowered aggregate RMW")
      }
      @debug.assert_eq(wast_to_module(printed).unwrap().fields, parsed.fields)
    }
  }
}

///|
test "Binaryen 132 rejects unsupported mixed or incomplete RMW order pairs" {
  for orders in ["relaxed acqrel", "seqcst relaxed", "relaxed"] {
    assert_true(
      wast_to_module("(module (func (struct.atomic.rmw.add \{orders} 0 0)))")
      is Err(_),
    )
  }
}

///|
test "Binaryen 132 linear atomic text preserves memory index offset width and order" {
  for order in ["seqcst", "acqrel", "relaxed"] {
    let source = "(module (memory $other 1 2) (memory $shared i64 1 2 shared) (func (result i64) (atomic.fence \{order}) (i64.atomic.store32 $shared \{order} offset=4294967297 align=4 (i64.const 0) (i64.const 7)) (i64.atomic.rmw32.add_u $shared \{order} offset=4294967297 align=4 (i64.const 0) (i64.const 2)) drop (i64.atomic.rmw32.cmpxchg_u $shared \{order} (i64.const 0) (i64.const 7) (i64.const 9)) drop (i64.atomic.load32_u $shared \{order} offset=4294967297 align=4 (i64.const 0))))"
    let parsed = match wast_to_module(source) {
      Ok(value) => value
      Err(err) => fail("ordered memory64 atomics: \{err}")
    }
    let printed = module_to_wast(parsed).unwrap()
    let lowered = wast_to_binary_module(printed).unwrap()
    assert_true(@validate.validate_module(lowered) is Ok(_))
    let @lib.CodeSec(bodies) = lowered.code_sec.unwrap()
    let @lib.Func(_, @lib.Expr(body)) = bodies[0]
    let expected = match order {
      "relaxed" => @lib.AtomicOrder::relaxed()
      "acqrel" => @lib.AtomicOrder::acq_rel()
      _ => @lib.AtomicOrder::seq_cst()
    }
    match body[body.length() - 1] {
      @lib.I64AtomicLoad32U(
        actual,
        @lib.MemArg(@lib.U32(2U), Some(@lib.MemIdx(1U)), @lib.U64(4294967297UL))
      ) => @debug.assert_eq(actual, expected)
      _ => fail("linear atomic memory arguments were lost")
    }
    @debug.assert_eq(wast_to_module(printed).unwrap().fields, parsed.fields)
  }
}

///|
test "Binaryen 132 accepts the released seqcst text spelling" {
  let source = "(module (type (struct (field i32))) (func (result i32) (struct.atomic.get seqcst 0 0 (struct.new 0 (i32.const 42)))))"
  let canonical = "(module (type (struct (field i32))) (func (result i32) (struct.atomic.get seq_cst 0 0 (struct.new 0 (i32.const 42)))))"
  let actual = match wast_to_binary_module(source) {
    Ok(value) => value
    Err(err) => fail("expected released seqcst spelling: \{err}")
  }
  let expected = match wast_to_binary_module(canonical) {
    Ok(value) => value
    Err(err) => fail("expected canonical seq_cst spelling: \{err}")
  }
  @debug.assert_eq(actual.code_sec, expected.code_sec)
}

///|
test "Binaryen 132 array atomic read text preserves orders and packed extensions" {
  for entry in [("get", "i32"), ("get_s", "i8"), ("get_u", "i16")] {
    let (opcode, storage) = entry
    let source = "(module (type (array (mut \{storage}))) (func (param (ref null 0)) (result i32) (array.atomic.\{opcode} relaxed 0 (local.get 0) (i32.const 0))))"
    let parsed = match wast_to_module(source) {
      Ok(value) => value
      Err(err) => fail("array atomic read: \{err}")
    }
    let output = wast_to_binary_module(module_to_wast(parsed).unwrap()).unwrap()
    assert_true(@validate.validate_module(output) is Ok(_))
    let body = match output.code_sec {
      Some(@lib.CodeSec([@lib.Func(_, @lib.Expr(body))])) => body
      _ => fail("expected one function")
    }
    match body[body.length() - 1] {
      @lib.ArrayAtomicGet(@lib.Relaxed, @lib.TypeIdx(0U)) =>
        assert_eq(opcode, "get")
      @lib.ArrayAtomicGetS(@lib.Relaxed, @lib.TypeIdx(0U)) =>
        assert_eq(opcode, "get_s")
      @lib.ArrayAtomicGetU(@lib.Relaxed, @lib.TypeIdx(0U)) =>
        assert_eq(opcode, "get_u")
      _ => fail("array atomic read opcode or order lost")
    }
  }
}

///|
test "Binaryen 132 GC atomic stores parse print validate and preserve binary order" {
  for order in ["seqcst", "acqrel", "relaxed"] {
    let source = "(module (type (struct (field (mut i32)))) (type (array (mut i32))) (func (param (ref null 0) (ref null 1)) (struct.atomic.set \{order} 0 0 (local.get 0) (i32.const 7)) (array.atomic.set \{order} 1 (local.get 1) (i32.const 0) (i32.const 9))))"
    let ast = match wast_to_module(source) {
      Ok(value) => value
      Err(err) => fail("GC atomic stores: \{err}")
    }
    let output = wast_to_binary_module(module_to_wast(ast).unwrap()).unwrap()
    assert_true(@validate.validate_module(output) is Ok(_))
    let @lib.CodeSec(bodies) = output.code_sec.unwrap()
    let @lib.Func(_, @lib.Expr(body)) = bodies[0]
    let expected = match order {
      "relaxed" => @lib.AtomicOrder::relaxed()
      "acqrel" => @lib.AtomicOrder::acq_rel()
      _ => @lib.AtomicOrder::seq_cst()
    }
    match (body[2], body[6]) {
      (@lib.StructAtomicSet(first, _, _), @lib.ArrayAtomicSet(second, _)) => {
        @debug.assert_eq(first, expected)
        @debug.assert_eq(second, expected)
      }
      _ => fail("atomic stores were changed during text lowering")
    }
  }
}

///|
test "Binaryen 132 memory authoring retains 64 bit limits and rejects overflowing literals" {
  let parsed = wast_to_binary_module(
    "(module (import \"env\" \"mem\" (memory $mem i64 4294967296 4294967297 shared)))",
  ).unwrap()
  let @lib.ImportSec(imports) = parsed.import_sec.unwrap()
  match imports[0] {
    @lib.Import(
      _,
      _,
      @lib.MemExternType(
        @lib.MemType(@lib.I64Limits(4294967296UL, Some(4294967297UL)), true)
      )
    ) => ()
    _ => fail("memory64 import limit or sharedness truncated")
  }
  for
    source in [
      "(module (memory 4294967296))", "(module (memory i64 18446744073709551616))",
      "(module (memory i64 0x10000000000000000))",
    ] {
    assert_true(wast_to_module(source) is Err(_))
  }
}

///|
test "Binaryen 132 linear atomic opcode matrix retains binary opcode and order bytes" {
  let lanes = [
    ("i32", "", 4),
    ("i64", "", 8),
    ("i32", "8", 1),
    ("i32", "16", 2),
    ("i64", "8", 1),
    ("i64", "16", 2),
    ("i64", "32", 4),
  ]
  let cases : Array[(String, Int, Int, Bool)] = []
  for lane_idx, lane in lanes {
    let (ty, width, align) = lane
    let extension = if width == "" { "" } else { "_u" }
    cases.push(
      ("\{ty}.atomic.load\{width}\{extension}", 0x10 + lane_idx, align, false),
    )
    cases.push(("\{ty}.atomic.store\{width}", 0x17 + lane_idx, align, false))
    for op_idx, op in ["add", "sub", "and", "or", "xor", "xchg", "cmpxchg"] {
      cases.push(
        (
          "\{ty}.atomic.rmw\{width}.\{op}\{extension}",
          0x1e + op_idx * 7 + lane_idx,
          align,
          true,
        ),
      )
    }
  }
  for entry in cases {
    let (name, opcode, align, pair) = entry
    for order_idx, order in ["seqcst", "acqrel", "relaxed"] {
      let ast = wast_to_binary_module(
        "(module (memory 1 1 shared) (func unreachable \{name} \{order} align=\{align}))",
      ).unwrap()
      let @lib.CodeSec(bodies) = ast.code_sec.unwrap()
      let @lib.Func(_, @lib.Expr(body)) = bodies[0]
      let bytes = @buffer.new()
      @binary.Encode::encode(body[1], bytes).unwrap()
      let encoded = bytes.to_bytes()
      assert_eq(encoded[0].to_int(), 0xfe)
      assert_eq(encoded[1].to_int(), opcode)
      let power = match align {
        1 => 0
        2 => 1
        4 => 2
        _ => 3
      }
      if order_idx == 0 {
        assert_eq(encoded[2].to_int(), power)
        assert_eq(encoded.length(), 4)
      } else {
        assert_eq(encoded[2].to_int(), power | 0x10)
        assert_eq(
          encoded[3].to_int(),
          if pair {
            order_idx * 0x11
          } else {
            order_idx
          },
        )
        assert_eq(encoded.length(), 5)
      }
    }
  }
  for entry in [("notify", 0, 4), ("wait32", 1, 4), ("wait64", 2, 8)] {
    let (name, opcode, align) = entry
    let ast = wast_to_binary_module(
      "(module (memory 1 1 shared) (func unreachable memory.atomic.\{name} align=\{align}))",
    ).unwrap()
    let @lib.CodeSec(bodies) = ast.code_sec.unwrap()
    let @lib.Func(_, @lib.Expr(body)) = bodies[0]
    let bytes = @buffer.new()
    @binary.Encode::encode(body[1], bytes).unwrap()
    assert_eq(bytes.to_bytes()[1].to_int(), opcode)
  }
}
