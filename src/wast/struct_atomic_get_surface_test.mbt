///|
test "wast_to_module parses folded struct atomic get instructions" {
  let src =
    #|(module
    #|  (type (struct (field i32) (field (mut i8)) (field (mut i16))))
    #|  (func (param (ref 0)) (result i32)
    #|    (struct.atomic.get acq_rel 0 0 (local.get 0)))
    #|  (func (param (ref 0)) (result i32)
    #|    (struct.atomic.get_s seq_cst 0 1 (local.get 0)))
    #|  (func (param (ref 0)) (result i32)
    #|    (struct.atomic.get_u acq_rel 0 2 (local.get 0))))
  let mod = match wast_to_module(src) {
    Ok(m) => m
    Err(e) => fail("expected folded struct atomic get parse success: \{e}")
  }
  match mod.fields {
    [
      TypeField(_),
      FuncField(func_get),
      FuncField(func_get_s),
      FuncField(func_get_u),
    ] => {
      match func_get.body {
        [LocalGet(Num(0U)), StructAtomicGet(AcqRel, Num(0U), 0U)] => ()
        _ => fail("expected folded struct.atomic.get body")
      }
      match func_get_s.body {
        [LocalGet(Num(0U)), StructAtomicGetS(SeqCst, Num(0U), 1U)] => ()
        _ => fail("expected folded struct.atomic.get_s body")
      }
      match func_get_u.body {
        [LocalGet(Num(0U)), StructAtomicGetU(AcqRel, Num(0U), 2U)] => ()
        _ => fail("expected folded struct.atomic.get_u body")
      }
    }
    _ => fail("expected type field followed by three functions")
  }
}

///|
test "module_to_wast preserves struct atomic get instruction keywords" {
  let src =
    #|(module
    #|  (type (struct (field i32) (field (mut i8)) (field (mut i16))))
    #|  (func (param (ref 0)) (result i32) (struct.atomic.get acq_rel 0 0 (local.get 0)))
    #|  (func (param (ref 0)) (result i32) (struct.atomic.get_s seq_cst 0 1 (local.get 0)))
    #|  (func (param (ref 0)) (result i32) (struct.atomic.get_u acq_rel 0 2 (local.get 0))))
  let mod = match wast_to_module(src) {
    Ok(m) => m
    Err(e) => fail("expected struct atomic get parse success: \{e}")
  }
  let text = match module_to_wast(mod) {
    Ok(t) => t
    Err(e) => fail("expected struct atomic get print success: \{e}")
  }
  assert_true(text.contains("struct.atomic.get acq_rel 0 0"))
  assert_true(text.contains("struct.atomic.get_s seq_cst 0 1"))
  assert_true(text.contains("struct.atomic.get_u acq_rel 0 2"))
}

///|
test "wast_to_binary_module lowers struct atomic get instructions" {
  let src =
    #|(module
    #|  (type (struct (field i32) (field (mut i8)) (field (mut i16))))
    #|  (func (param (ref 0)) (result i32) (struct.atomic.get acq_rel 0 0 (local.get 0)))
    #|  (func (param (ref 0)) (result i32) (struct.atomic.get_s seq_cst 0 1 (local.get 0)))
    #|  (func (param (ref 0)) (result i32) (struct.atomic.get_u acq_rel 0 2 (local.get 0))))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) => fail("expected struct atomic get lowering success: \{e}")
  }
  match lowered.code_sec {
    Some(
      @lib.CodeSec(
        [
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.LocalGet(@lib.LocalIdx(0U)),
                @lib.StructAtomicGet(
                  order0,
                  @lib.TypeIdx::TypeIdx(0U),
                  @lib.U32(0U)
                ),
              ]
            )
          ),
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.LocalGet(@lib.LocalIdx(0U)),
                @lib.StructAtomicGetS(
                  order1,
                  @lib.TypeIdx::TypeIdx(0U),
                  @lib.U32(1U)
                ),
              ]
            )
          ),
          @lib.Func(
            _,
            @lib.Expr(
              [
                @lib.LocalGet(@lib.LocalIdx(0U)),
                @lib.StructAtomicGetU(
                  order2,
                  @lib.TypeIdx::TypeIdx(0U),
                  @lib.U32(2U)
                ),
              ]
            )
          ),
        ]
      )
    ) => {
      @debug.assert_eq(order0, @lib.AtomicOrder::acq_rel())
      @debug.assert_eq(order1, @lib.AtomicOrder::seq_cst())
      @debug.assert_eq(order2, @lib.AtomicOrder::acq_rel())
    }
    _ =>
      fail("expected lowered code section with struct atomic get instructions")
  }
}
