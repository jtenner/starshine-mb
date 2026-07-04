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
  assert_true(text.contains("struct.atomic.get 0 0"))
  assert_true(text.contains("struct.atomic.get_s 0 1"))
  assert_true(text.contains("struct.atomic.get_u 0 2"))
}

///|
test "wast_to_module parses aggregate atomic rmw cmpxchg instructions" {
  let src =
    #|(module
    #|  (type (struct (field (mut i32))))
    #|  (type (array (mut i32)))
    #|  (func (param (ref 0)) (param i32) (result i32)
    #|    (struct.atomic.rmw.add 0 0 (local.get 0) (local.get 1)))
    #|  (func (param (ref 0)) (param i32) (result i32)
    #|    (struct.atomic.rmw.xchg 0 0 (local.get 0) (local.get 1)))
    #|  (func (param (ref 0)) (param i32) (param i32) (result i32)
    #|    (struct.atomic.rmw.cmpxchg 0 0 (local.get 0) (local.get 1) (local.get 2)))
    #|  (func (param (ref 1)) (param i32) (param i32) (result i32)
    #|    (array.atomic.rmw.add 1 (local.get 0) (local.get 1) (local.get 2)))
    #|  (func (param (ref 1)) (param i32) (param i32) (param i32) (result i32)
    #|    (array.atomic.rmw.cmpxchg 1 (local.get 0) (local.get 1) (local.get 2) (local.get 3))))
  let mod = match wast_to_module(src) {
    Ok(m) => m
    Err(e) => fail("expected aggregate atomic parse success: \{e}")
  }
  match mod.fields {
    [
      TypeField(_),
      TypeField(_),
      FuncField(f0),
      FuncField(f1),
      FuncField(f2),
      FuncField(f3),
      FuncField(f4),
    ] => {
      match f0.body {
        [
          LocalGet(Num(0U)),
          LocalGet(Num(1U)),
          StructAtomicRmw(@lib.AggregateAtomicRmwAdd, Num(0U), 0U),
        ] => ()
        _ => fail("expected struct atomic rmw.add body")
      }
      match f1.body {
        [
          LocalGet(Num(0U)),
          LocalGet(Num(1U)),
          StructAtomicRmw(@lib.AggregateAtomicRmwXchg, Num(0U), 0U),
        ] => ()
        _ => fail("expected struct atomic rmw.xchg body")
      }
      match f2.body {
        [
          LocalGet(Num(0U)),
          LocalGet(Num(1U)),
          LocalGet(Num(2U)),
          StructAtomicCmpxchg(Num(0U), 0U),
        ] => ()
        _ => fail("expected struct atomic cmpxchg body")
      }
      match f3.body {
        [
          LocalGet(Num(0U)),
          LocalGet(Num(1U)),
          LocalGet(Num(2U)),
          ArrayAtomicRmw(@lib.AggregateAtomicRmwAdd, Num(1U)),
        ] => ()
        _ => fail("expected array atomic rmw.add body")
      }
      match f4.body {
        [
          LocalGet(Num(0U)),
          LocalGet(Num(1U)),
          LocalGet(Num(2U)),
          LocalGet(Num(3U)),
          ArrayAtomicCmpxchg(Num(1U)),
        ] => ()
        _ => fail("expected array atomic cmpxchg body")
      }
    }
    _ => fail("expected parsed aggregate atomic fields")
  }
  let text = match module_to_wast(mod) {
    Ok(t) => t
    Err(e) => fail("expected aggregate atomic print success: \{e}")
  }
  assert_true(text.contains("struct.atomic.rmw.add 0 0"), msg=text)
  assert_true(text.contains("struct.atomic.rmw.xchg 0 0"), msg=text)
  assert_true(text.contains("struct.atomic.rmw.cmpxchg 0 0"), msg=text)
  assert_true(text.contains("array.atomic.rmw.add 1"), msg=text)
  assert_true(text.contains("array.atomic.rmw.cmpxchg 1"), msg=text)
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
