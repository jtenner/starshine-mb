///|
test "wast_to_binary_module appends implicit functypes after rec groups at flat type indices" {
  let src =
    #|(module
    #|  (rec
    #|    (type $a (struct))
    #|    (type $b (struct)))
    #|  (func (param (ref $a)) (result (ref null $b))
    #|    (ref.null $b)))
  let lowered = match wast_to_binary_module(src) {
    Ok(m) => m
    Err(e) =>
      fail("expected implicit functype after rec-group lowering success: \{e}")
  }
  match lowered.func_sec {
    Some(@lib.FuncSec([@lib.TypeIdx::TypeIdx(2U)])) => ()
    _ => fail("expected func section to point at flat type index 2")
  }
  match @validate.validate_module(lowered) {
    Ok(_) => ()
    Err(e) =>
      fail("expected rec-group implicit functype module to validate: \{e}")
  }
}
