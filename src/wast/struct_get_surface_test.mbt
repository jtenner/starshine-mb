///|
test "wast_to_module parses folded struct access instructions" {
  let src =
    #|(module
    #|  (type (struct (field i32) (field (mut i8)) (field (mut i16))))
    #|  (func (result i32)
    #|    (struct.get 0 0
    #|      (struct.new 0
    #|        (i32.const 1)
    #|        (i32.const 2)
    #|        (i32.const 3))))
    #|  (func (result i32)
    #|    (struct.get_s 0 1
    #|      (struct.new 0
    #|        (i32.const 4)
    #|        (i32.const 5)
    #|        (i32.const 6))))
    #|  (func (result i32)
    #|    (struct.get_u 0 2
    #|      (struct.new 0
    #|        (i32.const 7)
    #|        (i32.const 8)
    #|        (i32.const 9)))))
  let mod = match wast_to_module(src) {
    Ok(m) => m
    Err(e) => fail("expected folded struct access parse success: \{e}")
  }
  match mod.fields {
    [
      TypeField(_),
      FuncField(func_get),
      FuncField(func_get_s),
      FuncField(func_get_u),
    ] => {
      match func_get.body {
        [
          Const(I32Const, "1"),
          Const(I32Const, "2"),
          Const(I32Const, "3"),
          StructNew(Num(0U)),
          StructGet(Num(0U), 0U),
        ] => ()
        _ => fail("expected folded struct.get body")
      }
      match func_get_s.body {
        [
          Const(I32Const, "4"),
          Const(I32Const, "5"),
          Const(I32Const, "6"),
          StructNew(Num(0U)),
          StructGetS(Num(0U), 1U),
        ] => ()
        _ => fail("expected folded struct.get_s body")
      }
      match func_get_u.body {
        [
          Const(I32Const, "7"),
          Const(I32Const, "8"),
          Const(I32Const, "9"),
          StructNew(Num(0U)),
          StructGetU(Num(0U), 2U),
        ] => ()
        _ => fail("expected folded struct.get_u body")
      }
    }
    _ => fail("expected type field followed by three functions")
  }
}

///|
test "module_to_wast preserves struct access instruction keywords" {
  let src =
    #|(module
    #|  (type (struct (field i32) (field (mut i8)) (field (mut i16))))
    #|  (func (drop (struct.get 0 0 (struct.new 0 (i32.const 1) (i32.const 2) (i32.const 3)))))
    #|  (func (drop (struct.get_s 0 1 (struct.new 0 (i32.const 4) (i32.const 5) (i32.const 6)))))
    #|  (func (drop (struct.get_u 0 2 (struct.new 0 (i32.const 7) (i32.const 8) (i32.const 9)))))))
  let mod = match wast_to_module(src) {
    Ok(m) => m
    Err(e) => fail("expected struct access parse success: \{e}")
  }
  let text = match module_to_wast(mod) {
    Ok(t) => t
    Err(e) => fail("expected struct access print success: \{e}")
  }
  assert_true(text.contains("struct.get 0 0"))
  assert_true(text.contains("struct.get_s 0 1"))
  assert_true(text.contains("struct.get_u 0 2"))
}

///|
test "wast_to_binary_module lowers struct access instructions" {
  let src =
    #|(module
    #|  (type (struct (field i32) (field (mut i8)) (field (mut i16))))
    #|  (func (result i32)
    #|    (struct.get 0 0
    #|      (struct.new 0
    #|        (i32.const 1)
    #|        (i32.const 2)
    #|        (i32.const 3))))
    #|  (func (result i32)
    #|    (struct.get_s 0 1
    #|      (struct.new 0
    #|        (i32.const 4)
    #|        (i32.const 5)
    #|        (i32.const 6))))
    #|  (func (result i32)
    #|    (struct.get_u 0 2
    #|      (struct.new 0
    #|        (i32.const 7)
    #|        (i32.const 8)
    #|        (i32.const 9)))))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) => fail("expected struct access lowering success: \{e}")
  }
  match lowered.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.I32Const(@lib.I32(1)),
                @lib.I32Const(@lib.I32(2)),
                @lib.I32Const(@lib.I32(3)),
                @lib.StructNew(@lib.TypeIdx::TypeIdx(0U)),
                @lib.StructGet(@lib.TypeIdx::TypeIdx(0U), @lib.U32(0U)),
              ]
            )
          ),
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.I32Const(@lib.I32(4)),
                @lib.I32Const(@lib.I32(5)),
                @lib.I32Const(@lib.I32(6)),
                @lib.StructNew(@lib.TypeIdx::TypeIdx(0U)),
                @lib.StructGetS(@lib.TypeIdx::TypeIdx(0U), @lib.U32(1U)),
              ]
            )
          ),
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.I32Const(@lib.I32(7)),
                @lib.I32Const(@lib.I32(8)),
                @lib.I32Const(@lib.I32(9)),
                @lib.StructNew(@lib.TypeIdx::TypeIdx(0U)),
                @lib.StructGetU(@lib.TypeIdx::TypeIdx(0U), @lib.U32(2U)),
              ]
            )
          ),
        ]
      )
    ) => ()
    _ => fail("expected lowered code section with struct access instructions")
  }
}
