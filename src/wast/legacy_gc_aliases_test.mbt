///|
test "wast_to_binary_module lowers legacy gc reference aliases" {
  let src =
    #|(module
    #|  (table 1 anyref)
    #|  (func
    #|    (param anyref eqref i31ref structref arrayref nullref)
    #|    (result anyref structref arrayref nullref)
    #|    (ref.null struct)
    #|    (ref.null array)))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) => fail("expected legacy alias lowering success: \{e}")
  }
  match lowered.table_sec {
    Some(@lib.TableSec([@lib.Table(@lib.TableType(elem_type, _), _)])) =>
      assert_eq(
        elem_type,
        @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::any())),
      )
    _ => fail("expected lowered table section")
  }
  let env = @validate.Env::new().with_module(lowered)
  match env.resolve_functype(@lib.TypeIdx::new(0U)) {
    Some(@lib.FuncType(params, results)) => {
      assert_eq(params, [
        @lib.ValType::ref_type(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::any())),
        ),
        @lib.ValType::ref_type(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::eq())),
        ),
        @lib.ValType::ref_type(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::i31())),
        ),
        @lib.ValType::ref_type(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::struct_())),
        ),
        @lib.ValType::ref_type(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::array())),
        ),
        @lib.ValType::ref_type(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::none())),
        ),
      ])
      assert_eq(results, [
        @lib.ValType::ref_type(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::any())),
        ),
        @lib.ValType::ref_type(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::struct_())),
        ),
        @lib.ValType::ref_type(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::array())),
        ),
        @lib.ValType::ref_type(
          @lib.RefType::new(true, @lib.HeapType::abs(@lib.AbsHeapType::none())),
        ),
      ])
    }
    _ => fail("expected lowered function type")
  }
}
