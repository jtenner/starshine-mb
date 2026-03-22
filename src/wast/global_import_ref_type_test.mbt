///|
test "wast_to_module parses imported globals with exact typed ref types" {
  let src =
    #|(module
    #|  (type $b (struct))
    #|  (import "A" "b" (global $g (ref null (exact $b)))))
  let mod = match wast_to_module(src) {
    Ok(m) => m
    Err(e) =>
      fail("expected imported global exact ref parse success: \{e}")
  }
  match mod.fields {
    [TypeField(_), ImportField(im)] => {
      assert_eq(im.id, Some("$g"))
      match im.desc {
        Global(gt) => {
          assert_false(gt.mutable_)
          match gt.val_type {
            TypedFuncRef(HeapTypeRef::ExactTypeId("$b")) => ()
            _ => fail("expected nullable exact typed ref global import type")
          }
        }
        _ => fail("expected imported global descriptor")
      }
    }
    _ => fail("expected type field followed by imported global")
  }
}

///|
test "module_to_wast preserves imported globals with exact typed ref types" {
  let src =
    #|(module
    #|  (type $b (struct))
    #|  (import "A" "b" (global $g (ref null (exact $b)))))
  let mod = match wast_to_module(src) {
    Ok(m) => m
    Err(e) =>
      fail("expected imported global exact ref parse success: \{e}")
  }
  let text = match module_to_wast(mod) {
    Ok(t) => t
    Err(e) =>
      fail("expected imported global exact ref print success: \{e}")
  }
  assert_true(text.contains("(global $g (ref null (exact $b)))"))
}

///|
test "wast_to_binary_module lowers imported globals with exact typed ref types" {
  let src =
    #|(module
    #|  (type $b (struct))
    #|  (import "A" "b" (global $g (ref null (exact $b)))))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) =>
      fail("expected imported global exact ref lowering success: \{e}")
  }
  match lowered.import_sec {
    Some(@lib.ImportSec(imports)) => assert_eq(imports, [
      @lib.Import::new(
        @lib.Name::new("A"),
        @lib.Name::new("b"),
        @lib.ExternType::global(
          @lib.GlobalType::new(
            @lib.ValType::ref_type(
              @lib.RefType::new(
                true,
                @lib.HeapType::new(@lib.TypeIdx::new(0U)),
                exact=true,
              ),
            ),
            false,
          ),
        ),
      ),
    ])
    _ => fail("expected lowered import section with exact typed ref global")
  }
}
