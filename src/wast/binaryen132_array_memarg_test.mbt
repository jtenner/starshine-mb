///|
test "Binaryen 132 array memory arguments parse print and lower scalar and vector accesses" {
  for
    entry in [
      ("i32.load", "i32", ""),
      ("i64.load32_u", "i64", ""),
      ("v128.load", "v128", ""),
      ("i32.store", "", "(i32.const 42)"),
      ("v128.store", "", "(v128.const i32x4 1 2 3 4)"),
    ] {
    let (opcode, result, value) = entry
    let signature = if result == "" { "" } else { "(result \{result})" }
    let source = "(module (type $A (array (mut i32))) (func (param (ref null $A)) \{signature} (\{opcode} (type $A) offset=17 align=1 (local.get 0) (i32.const 4) \{value})))"
    let input = match wast_to_module(source) {
      Ok(input) => input
      Err(err) => fail("array syntax: \{err}")
    }
    let rendered = match module_to_wast(input) {
      Ok(text) => text
      Err(err) => fail(err)
    }
    let output = match wast_to_binary_module(rendered) {
      Ok(output) => output
      Err(err) => fail("array text roundtrip: \{err}")
    }
    let @lib.CodeSec(bodies) = output.code_sec.unwrap()
    let @lib.Func(_, @lib.Expr(body)) = bodies[0]
    match body[body.length() - 1] {
      @lib.ArrayLoad(
        _,
        @lib.TypeIdx(0U),
        @lib.MemArg(@lib.U32(0U), None, @lib.U64(17UL))
      )
      | @lib.ArrayStore(
        _,
        @lib.TypeIdx(0U),
        @lib.MemArg(@lib.U32(0U), None, @lib.U64(17UL))
      ) => ()
      _ => fail("array memory arguments lost during lowering")
    }
  }
}
